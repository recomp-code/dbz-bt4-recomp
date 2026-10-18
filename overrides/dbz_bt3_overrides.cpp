// Game override: Dragon Ball Z Budokai Tenkaichi 3 (NTSC-U, SLUS_219.78, entry 0x00100008),
// "BT4 Beta 14 Rev2" mod ISO.
//
// The mod keeps its code in cdrom0:\BIN\DBZP.BIN, loaded by 0x00100280 at 0x00334C00 (right after
// the ELF's .bss) and reached through hooks patched into the ELF (j into the overlay and back).
// The recompiler input is SLUS_219.78.combined (ELF + DBZP.BIN as an extra PT_LOAD, see
// ~/NBAStreetRecomp/dbz/tools/mkcombined.py), so that code is recompiled too.
//
// Pads: the game uses libpad2 over libdbc (DBCMAN.IRX + DS2U_D.IRX); the runtime only has an
// HLE stub for DBCMAN (version check), so the libpad2 calls the game's pad poll (0x00122A38)
// makes are answered natively from the runtime's pad state (keyboard / gamepad / live ring):
//   0x00296160 scePad2GetState(socket)            -> 1 (stable)
//   0x00296090 scePad2GetButtonProfile(socket, p) -> 4 bytes, all buttons + sticks
//   0x00295FB8 scePad2Read(socket, data)          -> 18 bytes: buttons (active low), RX RY LX LY,
//                                                    12 pressure bytes
// Sockets: 0x00122998 creates port 0's (stored at 0x00333900), 0x001229C8 port 1's (0x00333AC0).

#include "game_overrides.h"
#include "ps2_runtime.h"
#include "ps2_runtime_macros.h"
#include "Stubs/Pad.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>

#if defined(__EMSCRIPTEN__)
#include <emscripten.h>
static uint8_t *g_dbzRam = nullptr;
// Debugging from the page: Module._ps2xDbzRam() = guest RAM base in the wasm heap.
extern "C" EMSCRIPTEN_KEEPALIVE uint8_t *ps2xDbzRam() { return g_dbzRam; }
extern "C" EMSCRIPTEN_KEEPALIVE uint8_t *ps2xDbzPcmCap();
static PS2Runtime *g_dbzRuntime = nullptr;
// Module._ps2xDbzIopRam(): snapshot of the 2 MB IOP RAM (debugging)
extern "C" EMSCRIPTEN_KEEPALIVE uint8_t *ps2xDbzIopRam()
{
    static std::vector<uint8_t> copy(2u << 20);
    if (g_dbzRuntime) g_dbzRuntime->readIopMemory(0, copy.data(), copy.size());
    return copy.data();
}
// Module._ps2xDbzWatch(addr[, index]): guest write watchpoint ([watch] lines with pc/ra), 0 = off
extern "C" EMSCRIPTEN_KEEPALIVE void ps2xDbzWatch(uint32_t addr, uint32_t index)
{
    if (index >= 4u) return;
    g_ps2WriteWatch[index] = addr & PS2_RAM_MASK;
    uint32_t n = 0;
    for (uint32_t i = 0; i < 4u; i++) if (g_ps2WriteWatch[i]) n = i + 1;
    g_ps2WriteWatchCount = n;
}
#endif

// EE scheduler (EeScheduler.cpp): a guest PC range that only polls for an event, slept instead.
void ps2xAddEeIdleLoop(uint32_t begin, uint32_t end);

namespace
{
    constexpr uint32_t kPad2Read = 0x00295FB8u;
    constexpr uint32_t kPad2GetState = 0x00296160u;
    constexpr uint32_t kPad2GetButtonProfile = 0x00296090u;
    constexpr uint32_t kPadPortBase = 0x00333800u; // per port 0x1C0 bytes, socket id at +0x100

    bool envFlagSet(const char *name)
    {
        const char *value = std::getenv(name);
        return value && value[0] && value[0] != '0';
    }

    void configureCdImage()
    {
        PS2Runtime::IoPaths paths = PS2Runtime::getIoPaths();
        std::filesystem::path image;
        if (const char *env = std::getenv("PS2X_CD_IMAGE"); env && *env)
            image = env;
        if (image.empty() && !paths.elfDirectory.empty())
            image = paths.elfDirectory.parent_path() / "DBZBT4.iso";
        std::error_code ec;
        if (!image.empty() && std::filesystem::exists(image, ec))
        {
            paths.cdImage = image;
            PS2Runtime::setIoPaths(paths);
            std::cerr << "[DBZ BT3] CD image: " << image.string() << std::endl;
        }
        else
        {
            std::cerr << "[DBZ BT3] CD image not found (" << image.string() << "). Set PS2X_CD_IMAGE." << std::endl;
        }
    }

    // Socket id -> pad port, from the game's pad structs.
    int portOfSocket(uint8_t *rdram, uint32_t socket)
    {
        for (int port = 0; port < 2; ++port)
        {
            uint32_t id = 0;
            std::memcpy(&id, rdram + kPadPortBase + port * 0x1C0u + 0x100u, sizeof(id));
            if (id == socket)
                return port;
        }
        return -1;
    }

    // Reads the runtime pad (libpad layout: [2..3] buttons active low, [4..7] RX RY LX LY,
    // [8..19] pressure) through the scePad* stubs, into scratch space below the guest stack.
    bool readRuntimePad(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime, int port, uint8_t out[32])
    {
        static bool s_opened[2] = {false, false};
        R5900Context saved = *ctx;
        const uint32_t scratch = (GPR_U32(ctx, 29) - 0x200u) & ~0x3Fu;
        if (!s_opened[port])
        {
            s_opened[port] = true;
            SET_GPR_U32(ctx, 4, static_cast<uint32_t>(port));
            SET_GPR_U32(ctx, 5, 0u);
            SET_GPR_U32(ctx, 6, scratch);
            ps2_stubs::scePadPortOpen(rdram, ctx, runtime);
            SET_GPR_U32(ctx, 4, static_cast<uint32_t>(port));
            SET_GPR_U32(ctx, 5, 0u);
            SET_GPR_U32(ctx, 6, 1u);
            SET_GPR_U32(ctx, 7, 3u);
            ps2_stubs::scePadSetMainMode(rdram, ctx, runtime);
        }
        SET_GPR_U32(ctx, 4, static_cast<uint32_t>(port));
        SET_GPR_U32(ctx, 5, 0u);
        SET_GPR_U32(ctx, 6, scratch);
        ps2_stubs::scePadRead(rdram, ctx, runtime);
        const bool ok = GPR_U32(ctx, 2) != 0u;
        std::memcpy(out, rdram + scratch, 32);
        *ctx = saved;
        return ok;
    }

    void pad2GetState(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        (void)runtime;
        const int port = portOfSocket(rdram, GPR_U32(ctx, 4));
        SET_GPR_U32(ctx, 2, port == 0 ? 1u : 0u); // port 1: nothing plugged in
        ctx->pc = GPR_U32(ctx, 31);
    }

    void pad2GetButtonProfile(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        (void)runtime;
        const uint32_t dst = GPR_U32(ctx, 5);
        if (dst)
        {
            static const uint8_t kProfile[4] = {0xFF, 0xFF, 0xFF, 0xFF};
            std::memcpy(rdram + (dst & 0x01FFFFFFu), kProfile, sizeof(kProfile));
        }
        SET_GPR_U32(ctx, 2, 4u);
        ctx->pc = GPR_U32(ctx, 31);
    }

    void pad2Read(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const int port = portOfSocket(rdram, GPR_U32(ctx, 4));
        const uint32_t dst = GPR_U32(ctx, 5) & 0x01FFFFFFu;
        const uint32_t ra = GPR_U32(ctx, 31);
        uint8_t data[32];
        std::memset(data, 0xFF, sizeof(data));
        data[4] = data[5] = data[6] = data[7] = 0x80;
        for (int i = 8; i < 20; ++i)
            data[i] = 0;
        if (port == 0)
            readRuntimePad(rdram, ctx, runtime, port, data);
        std::memcpy(rdram + dst, data + 2, 18);
        SET_GPR_U32(ctx, 2, port == 0 ? 18u : static_cast<uint32_t>(-1));
        ctx->pc = ra;
    }

    PS2Runtime::RecompiledFunction g_originalAllocIopHeap = nullptr;
    void tracedAllocIopHeap(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t size = GPR_U32(ctx, 4);
        const uint32_t ra = GPR_U32(ctx, 31);
        g_originalAllocIopHeap(rdram, ctx, runtime);
        std::fprintf(stderr, "[DBZ BT3] sceSifAllocIopHeap(0x%x) = 0x%x ra=0x%x\n", size, GPR_U32(ctx, 2), ra);
    }

    PS2Runtime::RecompiledFunction g_originalChangePrio = nullptr;
    void tracedChangePrio(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t id = GPR_U32(ctx, 4), prio = GPR_U32(ctx, 5), ra = GPR_U32(ctx, 31);
        g_originalChangePrio(rdram, ctx, runtime);
        if (std::getenv("PS2X_DBZ_PRIO_LOG"))
            std::fprintf(stderr, "[DBZ BT3] ChangeThreadPriority(%u, %u) = %d ra=0x%x\n", id, prio, static_cast<int>(GPR_U32(ctx, 2)), ra);
    }

    // PS2X_DBZ_PART_LOG=1: logs the first calls of the character part packet builder 0x00111358
    // (a0 = character, bone pointers at a0+0xD6C) with the two bone matrices it will copy.
    PS2Runtime::RecompiledFunction g_originalPartBuilder = nullptr;
    void tracedPartBuilder(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        static int s_count = 0, s_calls = 0;
        const uint32_t obj = GPR_U32(ctx, 4);
        s_calls++;
        const uint32_t part0 = *reinterpret_cast<uint32_t *>(rdram + ((obj + 0x44u) & 0x1FFFFFFu));
        const uint16_t idx0 = *reinterpret_cast<uint16_t *>(rdram + ((part0 + 0xAu) & 0x1FFFFFFu));
        const uint32_t bone0 = *reinterpret_cast<uint32_t *>(rdram + ((obj + 0xD6Cu + idx0 * 4u) & 0x1FFFFFFu));
        const float *m0 = reinterpret_cast<const float *>(rdram + ((bone0 + 0x10u) & 0x1FFFFFFu));
        const bool zero = m0[0] == 0.0f && m0[5] == 0.0f && m0[10] == 0.0f;
        if (s_count < 60 && (zero || (s_calls % 500) == 0))
        {
            s_count++;
            const uint32_t part = *reinterpret_cast<uint32_t *>(rdram + ((obj + 0x44u) & 0x1FFFFFFu));
            const uint16_t boneIdx = *reinterpret_cast<uint16_t *>(rdram + ((part + 0xAu) & 0x1FFFFFFu));
            const uint32_t bone = *reinterpret_cast<uint32_t *>(rdram + ((obj + 0xD6Cu + boneIdx * 4u) & 0x1FFFFFFu));
            const float *m = reinterpret_cast<const float *>(rdram + ((bone + 0x10u) & 0x1FFFFFFu));
            std::fprintf(stderr, "[DBZ part] call %d obj=%08x part=%08x bone#%u=%08x a1=%08x a2=%u m0=(%g %g %g %g / %g %g %g %g / %g %g %g %g / %g %g %g %g)\n",
                         s_calls, obj, part, boneIdx, bone, GPR_U32(ctx, 5), GPR_U32(ctx, 6), m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12], m[13], m[14], m[15]);
        }
        g_originalPartBuilder(rdram, ctx, runtime);
    }

    // PS2X_DBZ_PCMCAP=1: records the 32 int16 input samples of each call of the EE sound mixer
    // 0x0028C950 (a1 = channel PCM) into a ring; Module._ps2xDbzPcmCap() -> [count u32][int16...]
    PS2Runtime::RecompiledFunction g_originalMixer = nullptr;
    constexpr uint32_t kPcmCapSamples = 48000 * 20;
    int16_t g_pcmCap[kPcmCapSamples];
    uint32_t g_pcmCapPos = 0;
    void tracedMixer(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t src = GPR_U32(ctx, 5) & 0x1FFFFFFu;
        for (int i = 0; i < 32; i++)
        {
            int16_t v;
            std::memcpy(&v, rdram + src + i * 2, 2);
            g_pcmCap[g_pcmCapPos % kPcmCapSamples] = v;
            g_pcmCapPos++;
        }
        g_originalMixer(rdram, ctx, runtime);
    }

    void applyDbzBt3(PS2Runtime &runtime)
    {
        if (envFlagSet("PS2X_DBZ_PCMCAP"))
        {
            g_originalMixer = runtime.lookupFunction(0x0028C950u);
            if (g_originalMixer)
                runtime.replaceFunction(0x0028C950u, tracedMixer);
        }
        if (envFlagSet("PS2X_DBZ_PART_LOG"))
        {
            g_originalPartBuilder = runtime.lookupFunction(0x00111358u);
            if (g_originalPartBuilder)
                runtime.replaceFunction(0x00111358u, tracedPartBuilder);
        }
        g_originalChangePrio = runtime.lookupFunction(0x002B0A70u);
        if (g_originalChangePrio)
            runtime.replaceFunction(0x002B0A70u, tracedChangePrio);
        g_originalAllocIopHeap = runtime.lookupFunction(0x002B8CE0u);
        if (g_originalAllocIopHeap)
            runtime.replaceFunction(0x002B8CE0u, tracedAllocIopHeap);
        configureCdImage();
#if defined(__EMSCRIPTEN__)
        g_dbzRam = runtime.memory().getRDRAM();
        g_dbzRuntime = &runtime;
#endif
        // Same patches as [patches] in ~/NBAStreetRecomp/dbz/config/config.toml, in guest RAM too
        // (0x001001D8 is in _start code the fallback interpreter runs): heap start 0x3C1200
        // (past DBZP.BIN's end, 0x3C01D4), game pool top 0x1E80000.
        {
            static constexpr uint32_t kPatches[][2] = {
                {0x001001D8u, 0x24841200u},
                {0x00254F90u, 0x24421200u},
                {0x00254F8Cu, 0x3C1001E8u},
                {0x00254F94u, 0x36100000u},
            };
            uint8_t *ram = runtime.memory().getRDRAM();
            for (const auto &patch : kPatches)
                std::memcpy(ram + patch[0], &patch[1], sizeof(uint32_t));
        }
        if (!envFlagSet("PS2X_DBZ_NO_PAD_HLE"))
        {
            runtime.replaceFunction(kPad2GetState, pad2GetState);
            runtime.replaceFunction(kPad2GetButtonProfile, pad2GetButtonProfile);
            runtime.replaceFunction(kPad2Read, pad2Read);
        }
        // SDK functions Ghidra/ps2_analyzer did not name; each spins in a "bind RPC until
        // cd->server != 0" loop because the runtime IOP has no server for its SID.
        struct Binding
        {
            uint32_t address;
            const char *handler;
        };
        static constexpr Binding kBindings[] = {
            {0x002A3B88u, "sceCdSearchFile"}, // 28-byte wrapper of 0x002A3888
            {0x002A3888u, "sceCdSearchFile"}, // _sceCdSearchFile: binds 0x80000597
        };
        for (const Binding &binding : kBindings)
        {
            if (!ps2_game_overrides::bindAddressHandler(runtime, binding.address, binding.handler))
                std::fprintf(stderr, "[DBZ BT3] could not bind 0x%08x to %s\n", binding.address, binding.handler);
        }
        std::fprintf(stderr, "[DBZ BT3] override applied\n");
    }
}

PS2_REGISTER_GAME_OVERRIDE("DBZ Budokai Tenkaichi 3 (SLUS_219.78)", "SLUS_219.78", 0x00100008u, 0u, applyDbzBt3)

#if defined(__EMSCRIPTEN__)
extern "C" EMSCRIPTEN_KEEPALIVE uint8_t *ps2xDbzPcmCap()
{
    static std::vector<uint8_t> out;
    out.resize(4 + kPcmCapSamples * 2);
    const uint32_t n = std::min<uint32_t>(g_pcmCapPos, kPcmCapSamples);
    std::memcpy(out.data(), &n, 4);
    for (uint32_t i = 0; i < n; i++)
    {
        const int16_t v = g_pcmCap[(g_pcmCapPos - n + i) % kPcmCapSamples];
        std::memcpy(out.data() + 4 + i * 2, &v, 2);
    }
    return out.data();
}
#endif

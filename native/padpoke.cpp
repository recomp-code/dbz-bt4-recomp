// padpoke <game pid> <buttons hex> <ms> : holds buttons in the live ring header (as the GS host window would)
#include "/Users/miguelangel/NBAStreetRecomp/bt3mod/ps2xRuntime/src/lib/ps2_live_ring.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
int main(int argc, char **argv)
{
    std::string name = ps2live::objectName(ps2live::kPosixMappingName, std::string(argv[1]));
    int fd = shm_open(name.c_str(), O_RDWR, 0);
    if (fd < 0) { perror("shm_open"); return 1; }
    auto *h = (ps2live::RingHeader *)mmap(nullptr, sizeof(ps2live::RingHeader), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    uint32_t old = h->padButtons;
    const uint32_t b = (uint32_t)strtoul(argv[2], nullptr, 16);
    for (int i = 0; i < atoi(argv[3]); ++i) { h->padButtons = b; usleep(1000); }   // the host republishes every vsync

    h->padButtons = old;
    printf("poked %s (was %x)\n", argv[2], old);
}

/*
 * Watch a specified serial port for transitions that might be 1PPS.
 */
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifndef S_SPLINT_S
#include <unistd.h>
#endif /* S_SPLINT_S */
#include <fcntl.h>	/* needed for open() and friends */
#include <sys/ioctl.h>
#include <errno.h>
#include <time.h>

struct assoc {
    int mask;
    char *string;
};

/*
 * Possible pins for PPS: DCD, CTS, RTS, RI, DSR. Pinouts:
 *
 * DB9  DB25  Name      Full name
 * ---  ----  ----      --------------------
 *  3     2    TXD  --> Transmit Data
 *  2     3    RXD  <-- Receive Data
 *  7     4    RTS  --> Request To Send
 *  8     5    CTS  <-- Clear To Send
 *  6     6    DSR  <-- Data Set Ready
 *  4    20    DTR  --> Data Terminal Ready
 *  1     8    DCD  <-- Data Carrier Detect
 *  9    22    RI   <-- Ring Indicator
 *  5     7    SG       Signal ground
 */
const static struct assoc hlines[] = {
    {TIOCM_CD, "TIOCM_CD"},
    {TIOCM_RI, "TIOCM_RI"},
    {TIOCM_DSR, "TIOCM_DSR"},
    {TIOCM_CTS, "TIOCM_CTS"},
};


int main(int argc, char *argv[])
{
    struct timespec ts;
    int fd = open(argv[1], O_RDONLY);

    if (fd == -1) {
	(void)fprintf(stderr,
		      "open(%s) failed: %d %.40s\n",
		      argv[1], errno, strerror(errno));
	return 1;
    }

    (void)printf("Beginning wait...\n");

    for (;;) {
	if (ioctl(fd, TIOCMIWAIT, TIOCM_CD|TIOCM_DSR|TIOCM_CAR|TIOCM_RI|TIOCM_CTS) != 0) {
	    (void)fprintf(stderr,
			  "PPS ioctl(TIOCMIWAIT) failed: %d %.40s\n",
			  errno, strerror(errno));
	    break;
	} else {
	    const struct assoc *sp;
	    int handshakes;

	    clock_gettime(CLOCK_REALTIME, &ts);
	    ioctl(fd, TIOCMGET, &handshakes);
	    (void)fprintf(stdout, "%10ld %10ld", ts.tv_sec, ts.tv_nsec);
	    for (sp = hlines;
		 sp < hlines + sizeof(hlines)/sizeof(hlines[0]);
		 sp++)
		if ((handshakes & sp->mask) != 0) {
		    (void)fputc(' ', stdout);
		    (void)fputs(sp->string, stdout);
		}
	    (void)fputc('\n', stdout);
	}
    } 
}

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

typedef unsigned char uchar;
#include "nvram.h"

static uchar nvbuf[512];

static int nvget(char *img) {
	int fd;
	int x;
	fd = open(img, O_RDONLY);
	if (fd < 0) return -1;
	x = read(fd, nvbuf, sizeof(nvbuf));
	close(fd);
	if (x < 0) return -1;
	return 0;
}

static int nvset(char *img) {
	int fd;
	int x, y;
	fd = open(img, O_WRONLY | O_CREAT, 0666);
	if (fd < 0) return -1;
	x = write(fd, nvbuf, sizeof(nvbuf));
	y = close(fd);
	if (x < 0 || y < 0) return -1;
	return 0;
}

static int checksum(struct wizcfg *cfg) {
	uchar *buf = (uchar *)cfg;
	long cs = 0;	// must be >= 32 bits!
	long bcs;	// ('')
	int x;
	bcs = cfg->chksum[0] | (cfg->chksum[1] << 8) |
		(cfg->chksum[2] << 16) | (cfg->chksum[3] << 24);
	for (x = 0; x < sizeof(*cfg) - sizeof(cfg->chksum); ++x) {
		cs += buf[x];
	}
	return (cs == bcs);
}

static void setchksum(struct wizcfg *cfg) {
	uchar *buf = (uchar *)cfg;
	long cs = 0;	// must be >= 32 bits!
	int x;
	for (x = 0; x < sizeof(*cfg) - sizeof(cfg->chksum); ++x) {
		cs += buf[x];
	}
	cfg->chksum[0] = cs & 0xff;
	cfg->chksum[1] = (cs >> 8) & 0xff;
	cfg->chksum[2] = (cs >> 16) & 0xff;
	cfg->chksum[3] = (cs >> 24) & 0xff;
}

static void help(char *arg0) {
	fprintf(stderr, "WIZCFG for NVRAM images, v1.0\n");
	fprintf(stderr, "Usage: %s [options] nvram-img\n"
			"Options:\n"
			"    -n CID  Client node ID\n"
			"    -i IP   Client IP addr\n"
			"    -g GW   Gateway IP addr\n"
			"    -s MS   Subnet mask\n"
			"    -m MA   MAC address\n"
			"    -# SID,IP,PT[,KP] Socket # (0-7) definition\n"
		, arg0);
}

static void show(struct wizcfg *cfg) {
	int ns;
	int x;
	struct wizsok *sok;

	printf("Node ID:  %2XH\n", cfg->pmagic);
	printf("IP Addr:  %d.%d.%d.%d\n",
		cfg->sipr[0], cfg->sipr[1], cfg->sipr[2], cfg->sipr[3]);
	printf("Gateway:  %d.%d.%d.%d\n",
		cfg->gar[0], cfg->gar[1], cfg->gar[2], cfg->gar[3]);
	printf("Subnet:   %d.%d.%d.%d\n",
		cfg->subr[0], cfg->subr[1], cfg->subr[2], cfg->subr[3]);
	printf("MAC:      %02X:%02X:%02X:%02X:%02X:%02X\n",
		cfg->shar[0], cfg->shar[1], cfg->shar[2],
		cfg->shar[3], cfg->shar[4], cfg->shar[5]);
	ns = 0;
	for (x = 0; x < 8; ++x) {
		sok = &cfg->sockets[x];
		if (sok->cpnet != 0x31) continue;
		++ns;
		printf("Socket %d: %02XH %d.%d.%d.%d %d %d\n", x,
			sok->sid,
			sok->dipr[0], sok->dipr[1], sok->dipr[2], sok->dipr[3],
			(sok->dport[0] << 8) | sok->dport[1],
			sok->kpalvtr * 5);
	}
	if (!ns) {
		printf("No Sockets Configured\n");
	}
}

int parse_nid(uchar *out, char *str) {
	unsigned int b0;
	if (!str) return 0;
	if (sscanf(str, "%x", &b0) != 1) {
		return -1;
	}
	if (b0 > 255) {
		return -2;
	}
	out[0] = b0;
	return 0;
}

int parse_ip(uchar *out, char *str) {
	unsigned int b0, b1, b2, b3;
	if (!str) return 0;
	if (sscanf(str, "%u.%u.%u.%u", &b0, &b1, &b2, &b3) != 4) {
		return -1;
	}
	if (b0 > 255 || b1 > 255 || b2 > 255 || b3 > 255) {
		return -2;
	}
	out[0] = b0;
	out[1] = b1;
	out[2] = b2;
	out[3] = b3;
	return 0;
}

int parse_mac(uchar *out, char *str) {
	unsigned int b0, b1, b2, b3, b4, b5;
	if (!str) return 0;
	if (sscanf(str, "%x:%x:%x:%x:%x:%x", &b0, &b1, &b2, &b3, &b4, &b5) != 6) {
		return -1;
	}
	if (b0 > 255 || b1 > 255 || b2 > 255 || b3 > 255 || b4 > 255 || b5 > 255) {
		return -2;
	}
	out[0] = b0;
	out[1] = b1;
	out[2] = b2;
	out[3] = b3;
	out[4] = b4;
	out[5] = b5;
	return 0;
}

int parse_port(uchar *out, char *str) {
	unsigned int b0;
	if (!str) return 0;
	if (sscanf(str, "%u", &b0) != 1) {
		return -1;
	}
	if (b0 > 65535) {
		return -2;
	}
	out[0] = (b0 >> 8) & 0xff;
	out[1] = b0 & 0xff;
	return 0;
}

int parse_keep(uchar *out, char *str) {
	unsigned int b0;
	if (!str) return 0;
	if (sscanf(str, "%u", &b0) != 1) {
		return -1;
	}
	b0 = (b0 + 4) / 5;
	if (b0 > 255) {
		return -2;
	}
	out[0] = b0 & 0xff;
	return 0;
}

static int parse_sok(struct wizsok *sok, char *str) {
	char *s0, *s1, *s2, *s3;
	if (str == NULL) return 0;
	s0 = strtok(str, ",");
	s1 = strtok(NULL, ",");
	s2 = strtok(NULL, ",");
	s3 = strtok(NULL, ",");
	if (s0 == NULL || s1 == NULL || s2 == NULL) {
		return -1;
	}
	if (parse_nid(&sok->sid, s0) < 0) return -1;
	if (parse_ip(sok->dipr, s1) < 0) return -1;
	if (parse_port(sok->dport, s2) < 0) return -1;
	if (parse_keep(&sok->kpalvtr, s3) < 0) return -1;
	sok->cpnet = 0x31;
	return 0;
}

static char *cid = NULL;
static char *sipr = NULL;
static char *gar = NULL;
static char *subr = NULL;
static char *shar = NULL;
static char *soks[8] = { NULL };

int parse(struct wizcfg *cfg) {
	int x;
	if (parse_nid(&cfg->pmagic, cid) < 0) return -1;
	if (parse_ip(cfg->sipr, sipr) < 0) return -1;
	if (parse_ip(cfg->subr, subr) < 0) return -1;
	if (parse_ip(cfg->gar, gar) < 0) return -1;
	if (parse_mac(cfg->shar, shar) < 0) return -1;
	for (x = 0; x < 8; ++x) {
		if (parse_sok(&cfg->sockets[x], soks[x]) < 0) return -1;
	}
}

int main(int argc, char **argv) {
	int fd;
	int x;
	int ns;
	int set = 0;
	int new = 0;
	int verbose = 0;
	char *img;
	struct wizcfg *cfg;
	struct wizsok *sok;

	extern char *optarg;
	extern int optind;

	while ((x = getopt(argc, argv, "n:i:g:s:m:0:1:2:3:4:5:6:7:v")) != EOF) {
		switch (x) {
		case 'n':
			cid = optarg;
			++set;
			break;
		case 'i':
			sipr = optarg;
			++set;
			break;
		case 'g':
			gar = optarg;
			++set;
			break;
		case 's':
			subr = optarg;
			++set;
			break;
		case 'm':
			shar = optarg;
			++set;
			break;
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
			soks[x - '0'] = optarg;
			++set;
			break;
		case 'v':
			++verbose;
			break;
		default:
			help(argv[0]);
			return 1;
		}
	}
	if (optind >= argc) {
		help(argv[0]);
		return 1;
	}
	img = argv[optind];
	if (nvget(img) < 0) {
		if (set) {
			printf("Initializing new NVRAM block\n");
			memset(nvbuf, 0xff, sizeof(nvbuf));
			++new;
		} else {
			perror(img);
			return 1;
		}
	}
	cfg = (struct wizcfg *)nvbuf;
	if (!new && !checksum(cfg)) {
		printf("NVRAM block not initialized\n");
		return 1;
	}
	if (!set) {
		show(cfg);
		return 0;
	}
	if (parse(cfg) < 0) {
		fprintf(stderr, "Syntax error\n");
		return 1;
	}
	if (verbose) {
		show(cfg);
	}
	setchksum(cfg);
	if (nvset(img) < 0) {
		perror(img);
		return 1;
	}
	return 0;
}

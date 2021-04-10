/*
 * Layout of NVRAM block used to store CP/NET configuration.
 */

/*
 * Unused bytes should be initialized to 0xff
 * (buffer is initially set to all 0xff).
 *
 * NOTE: Erased FLASH memory is 0xff, FRAM ships as 0x00.
 */

struct wizsok {
	uchar	_resv1[4];
	uchar	cpnet;		// Sn_PORT0: 0x31 if configured for CP/NET
	uchar	sid;		// Sn_PORT1: CP/NET server node ID
	uchar	_resv2[6];
	uchar	dipr[4];	// destination (server) IP address
	uchar	dport[2];	// destination (server) port
	uchar	_resv3[11];
	uchar	kpalvtr;	// moved to Sn_KPALVTR in W5500
	uchar	_resv4[2];
};

struct wizcfg {
	uchar	_resv1;
	uchar	gar[4];		// gateway IP address
	uchar	subr[4];	// subnet mask
	uchar	shar[6];	// MAC address
	uchar	sipr[4];	// client IP address
	uchar	_resv2[10];
	uchar	pmagic;		// client CP/NET node ID
	uchar	_resv3[2];

	struct wizsok sockets[8];

	uchar	cfgtbl[38];	// CP/NET config table template

	uchar	_resv4[182];	// for expansion
	uchar	chksum[4];	// 32-bit sum of first 508 bytes, little-endian
};

/* sizeof(struct wizcfg) == 512 */
/* sizeof(struct wizsok) == 32 */

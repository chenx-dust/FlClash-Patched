#include <sys/types.h>

// sys/kern_control.h is missing from the iOS SDK, and the utun descriptor can
// only be told apart by the kernel control it is connected to.
#define CTLIOCGINFO 0xc0644e03UL
struct ctl_info {
  u_int32_t ctl_id;
  char ctl_name[96];
};
struct sockaddr_ctl {
  u_char sc_len;
  u_char sc_family;
  u_int16_t ss_sysaddr;
  u_int32_t sc_id;
  u_int32_t sc_unit;
  u_int32_t sc_reserved[5];
};

/*
 * init.c — monolithic initramfs init
 *
 * Minimal init for the monolithic initramfs.
 * The klibc mount() libc function works for squashfs in the initramfs
 * but not for virtual filesystems (proc/sysfs). We skip those mounts
 * and let the kernel handle them, then chroot to the squashfs root.
 */
#include <unistd.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <string.h>

static inline dev_t makedev(unsigned major, unsigned minor) {
	return (major << 8) | minor;
}

static void die(const char *msg) {
	write(2, msg, strlen(msg));
	write(2, "\n", 1);
	_exit(1);
}

static void mkdir_p(const char *path) {
	char tmp[256];
	size_t i;
	for (i = 0; path[i]; i++)
		tmp[i] = path[i];
	for (i = 1; i < sizeof(tmp) - 1; i++) {
		if (tmp[i] == '/') {
			tmp[i] = 0;
			mkdir(tmp, 0755);
			tmp[i] = '/';
		}
	}
	mkdir(tmp, 0755);
}

int main(void) {
	mkdir_p("/mnt/oldroot");
	mkdir_p("/mnt");

	/* Wait up to 60s for /dev/sda2 to appear */
	int tries = 0;
	while (access("/dev/sda2", F_OK) != 0 && tries < 60) {
		mknod("/dev/sda2", S_IFBLK | 0660, makedev(8, 2));
		sleep(1);
		tries++;
	}

	/* Mount squashfs root - klibc mount() works for this */
	if (mount("/dev/sda2", "/mnt", "squashfs", MS_RDONLY, NULL) < 0)
		die("mount squashfs");

	/* chroot to new root */
	if (chroot("/mnt") < 0) die("chroot");
	if (chdir("/") < 0) die("chdir");

	execl("/init", "/init", NULL);
	die("exec /init");
}

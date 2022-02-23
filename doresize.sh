if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root.\n"
  exit 1
fi

ROOT_PART="$(findmnt / -o source -n)"
ROOT_DEV="/dev/$(lsblk -no pkname "$ROOT_PART")"
PART_NUM="$(echo "$ROOT_PART" | grep -o "[[:digit:]]*$")"

apt install parted

LAST_PART_NUM=$(parted "$ROOT_DEV" -ms unit s p | tail -n 1 | cut -f 1 -d:)

if [ $LAST_PART_NUM -ne $PART_NUM ]; then
  printf "$ROOT_PART is not the last partition. Please disable swap.\n"
  exit 1
fi

PART_START=$(parted "$ROOT_DEV" -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
fdisk "$ROOT_DEV" <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF

cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs "$ROOT_PART" &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
chmod +x /etc/init.d/resize2fs_once
update-rc.d resize2fs_once defaults
#!/bin/sh
# android的linux部署与控制面板独立无依赖脚本

# 使用方法：
# * 手机 root
# * 安装ssh终端应用；建议安装 termux 来使用本脚本，同时它也是无需root可以使用linux绝大多功能的应用;可选的还有connectbot,termius，它们用法略有不同;
# * 授予ssh终端应用 root 权限
# * 打开termux

# !!!!!!!!!!!! 下面步骤为创建快捷命令仅操作1次的步骤开始 !!!!!!!!!!!!
# * 执行 cat >> ~/.bash_profile
# * 输入 alias linux='sh0=${TMPDIR}/android-linux.sh; test ! -f ${sh0}  && curl -vvv -lo ${sh0} "https://raw.githubusercontent.com/qidizi/android-archlinuxarm-deploy/master/archlinux-for-mi9-q.sh" ; test ! -f ${sh0}  && echo "脚本未下载请重试"; test -f ${sh0}  && /system/bin/sh ${sh0}; test "$?" != "0" && echo "执行脚本出错，信息如上";'
# * 回车换行后，按 ctrl+d 组合键保存
# * 执行 source ~/.bash_profile 让快捷命令当前session生效
# !!!!!!!!!!!! 仅操作1次的步骤结束 !!!!!!!!!!!!

# * 执行 linux 打开面板，根据提示操作即可

# 本脚本测试：
# 小米9 android 10
#
####### 编码 ######
# * 使用单中括号，不使用双中括号（不分词），可能有空白变量使用双引号
# * if中使用 = 面不是 ==
# * 本脚本尽量按照POSIX sh标准编写

#######config########
# todo 需要调试时，使用sh -x 调用本脚本即可

# 远程git版本地址
GIT_SRC="https://raw.githubusercontent.com/qidizi/android-archlinuxarm-deploy/master/"
# 版本,更新这个版本，必须同时修改版本检查文件，否则升级逻辑将异常
VER=20190824
# 本脚本远程地址
SRC_URL="${GIT_SRC}archlinux-for-mi9-q.sh"
# 本脚本最后版本号远程url
LAST_URL="${SRC_URL}.last"
# 我的工具集目录
DATA_ROOT="/data/linux/"
# bin为我的扩展可执行目录
BUSY_BOX="${DATA_ROOT}busybox"
# linux安装包下载地址,使用清华的源
REPO_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/"
# busybox 下载地址
BUSY_BOX_URL="https://www.busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l"
# 镜像url
LINUX_URI="${REPO_MIRROR}os/ArchLinuxARM-aarch64-latest.tar.gz"
# 安装包保存路径；用于缓存，重新部署时可以重复使用，无需重新下载；
LINUX_IMG="${DATA_ROOT}linux.dl"
# 解压后的 linux  系统根目录路径
CHROOT_DIR="${DATA_ROOT}mnt"
# linux解压后目录
LINUX_DIR="${DATA_ROOT}linux"
# DNS 1
DNS1="114.114.114.114"
# sdcard下的目录要挂载到linux中的路径，可选
MOUNT_SDCARD_PATH="/sdcard/mount2linux"
# su 的路径
SU_PATH="/system/xbin/su"
# 主机名，屏小限一字母
HOST_NAME="l"
# 启动后立即执行的脚本
RUN_AFTER_START="/etc/run_after_linux_start.sh"
# 停止前执行
RUN_BEFORE_STOP="/etc/run_before_linux_stop.sh"

#########

# 部署linux
linuxDeploy() {
    ${DEBUG_ON}

    if [ -e "${LINUX_IMG}/etc/ssh" ]; then
        # 只有安装才会提醒
        ${DEBUG_OFF}
        rn_echo "系统安装包中文件将会覆盖相同文件，确定重新部署？请输入Y："
        read -r yes
        ${DEBUG_ON}

        if [ "${yes}" != "Y" ]; then
            echo "部署被取消"
            exit
        fi
    fi

    rn_echo "开始重新部署linux..."
    needDownload=0

    if [ ! -f "${LINUX_IMG}" ]; then
        # linux安装包有缓存
        needDownload="Y"
    else
        st=$(stat -c "下载时间：%y，%s 字节" ${LINUX_IMG})
        ${DEBUG_OFF}
        rn_echo "发现${st}的linux安装包：${LINUX_IMG}"
        echo "可使用该包部署后升级系统而不必重新下载"
        echo "包下载慢，下载过程可取消继续使用旧包"
        echo "也可输入 Y 强制立刻重新下载，请选择："
        read -r needDownload
        ${DEBUG_ON}
    fi

    if [ "${needDownload}" = "Y" ]; then
        echo "开始下载linux安装包..."
        # 先下载到临时文件，覆盖前后悔后，可以取消继续使用
        tmp="${LINUX_IMG}.dl.tmp"
        curl --location -vvv --url "${LINUX_URI}" --output "${tmp}"
        fail2die "下载失败，请重试" "下载完成"
        echo "开始移动下载好的包..."
        mv -vvv -f "${tmp}" "${LINUX_IMG}"
        fail2die "移动失败" "移动成功"
    fi

    rn_echo "尝试解压 ${LINUX_IMG} 至 ${LINUX_DIR} ..."
    "${BUSY_BOX}" tar -vvvxpf ${LINUX_IMG} -C ${LINUX_DIR}
    fail2die "解压异常" "解压完成"

    rn_echo
    linuxConfig "n"
    echo "部署完成"
}

# 配置linux
linuxConfig() {
    ${DEBUG_ON}
    rn_echo

    if [ "$1" != "n" ]; then
        ${DEBUG_OFF}
        echo "原有配置信息将被清除"
        echo "确定要重新配置？请输入 Y："
        read -r yes
        ${DEBUG_ON}

        if [ "${yes}" != "Y" ]; then
            rn_echo "操作被取消"
            exit
        fi
    fi

    ${DEBUG_OFF}
    while true; do
        rn_echo "请输入用户名[屏小限从26个小写字母a至z任选其一]："
        read -r USER_NAME
        ok=$(echo "${USER_NAME}" | grep -e "^[a-z]$")

        if [ "${ok}" != "${USER_NAME}" ]; then
            echo "非法用户名"
            continue
        fi

        break
    done

    ${DEBUG_ON}

    if [ ! -f "${LINUX_DIR}${RUN_AFTER_START}" ]; then
        # 创建启动后执行的脚本说明

        # shellcheck disable=SC2059
        printf "
#!/bin/bash

# chroot linux没有普通的linux开机处理逻辑

# 如果您有需要启动linux后立刻执行的任务，请在此添加
# 您需要自行保证本脚本正确执行

# 屏小，初始主机名为单字母
hostname ${HOST_NAME}

        " >"${LINUX_DIR}${RUN_AFTER_START}"
    fi

    if [ ! -f "${LINUX_DIR}${RUN_BEFORE_STOP}" ]; then
        # 创建停止前执行的脚本说明

        printf "
#!/bin/bash

# chroot linux没有普通的linux停机处理逻辑

# 如果您有需要停止linux前立刻执行的任务，请在此添加
# 您需要自行保证本脚本正确执行
        " >"${LINUX_DIR}${RUN_BEFORE_STOP}"
    fi

    # 删除同名旧用户信息
    # 用户组
    del_append "${LINUX_DIR}/etc/group" "/^${USER_NAME}:.*/d" ""
    del_append "${LINUX_DIR}/etc/group" "/:(,[^:]+)*${USER_NAME}$/d" ""
    # 旧用户
    # root:x:0:0::/root:/bin/bash
    del_append "${LINUX_DIR}/etc/passwd" "/^${USER_NAME}:.*/d" ""
    # 旧用户密码
    del_append "${LINUX_DIR}/etc/shadow" "/^${USER_NAME}:.*/d" ""

    # 因为android的默认必须的用户已经占用低位id，所以，linux新用户要防止与android用户冲突
    # 对行用查找，并对匹配进行替换
    rn_echo "调高 uid 与 gid 数值下限限制..."
    sed -i 's/^[#]*UID_MIN.*/UID_MIN 5000/' "${LINUX_DIR}/etc/login.defs"
    sed -i 's/^[#]*GID_MIN.*/GID_MIN 5000/' "${LINUX_DIR}/etc/login.defs"
    # 主机名解析到loopback
    del_append "${LINUX_DIR}/etc/hosts" "/^.*127.0.0.1.*/d" "127.0.0.1 ${HOST_NAME}"
    # arch linux 这个文件指向不存在文件（是一个链接），需要先删除再创建
    dns_f="${LINUX_DIR}/etc/resolv.conf"
    ${BUSY_BOX} rm -fv "${dns_f}"
    # 指定dns
    echo "修改dns"
    echo "nameserver ${DNS1}" >"${dns_f}"

    # 使用指定的源
    ml="${LINUX_DIR}/etc/pacman.d/mirrorlist"
    echo "SigLevel = TrustAll" >"${ml}"
    echo "# 官方源" >"${ml}"
    # shellcheck disable=SC2129
    echo "# Server = http://mirror.archlinuxarm.org/\$arch/\$repo" >>"${ml}"
    echo "# 清华源" >>"${ml}"
    echo "Server = ${REPO_MIRROR}\$arch/\$repo" >>"${ml}"

    #修改主机名方便手机上更短;毕竟手机宽度比较小，主机名+路径，输入命令过多就容易换行；
    echo "${HOST_NAME}" >${LINUX_DIR}/etc/hostname
    ssh_cfg="${LINUX_DIR}/etc/ssh/sshd_config"
    #删除注释行
    # 修改ssh 端口；仅允许root从内网登录
    del_append "${ssh_cfg}" "/^[#]*ListenAddress.*$/d" "ListenAddress 0.0.0.0"

    ${DEBUG_OFF}
    while true; do
        rn_echo "请输入sshd端口[1～65535任一数字]："
        read -r SSH_PORT
        ok=$(echo "${SSH_PORT}" | grep -e "^[1-9][0-9]*$")

        if [ "${ok}" != "${SSH_PORT}" ]; then
            echo "非法，请重新输入"
            continue
        fi

        break
    done

    ${DEBUG_ON}

    del_append "${ssh_cfg}" "/^[#]*Port.*$/d" "Port ${SSH_PORT}"
    del_append "${ssh_cfg}" "/^[#]*AllowUsers.*$/d" "AllowUsers ${USER_NAME}@127.0.0.* ${USER_NAME}@10.* ${USER_NAME}@192.168.*"
    ssh4root="no"

    if [ "$USER_NAME" = "root" ]; then
        echo "允许root通过ssh登录"
        ssh4root="yes"
    else
        echo "禁止root登录ssh"
    fi

    # 是否允许root使用ssh
    del_append "${ssh_cfg}" "/^[#]*PermitRootLogin.*$/d" "PermitRootLogin ${ssh4root}"
    echo "挂载分区"
    mountAll
    echo "开始生成ssh密钥 ..."
    chroot_exec ssh-keygen -A

    chroot_exec useradd -m -d "/home/${USER_NAME}" --no-user-group --groups wheel "${USER_NAME}"
    rn_echo "请配置用户 ${USER_NAME} 的密码..."
    chroot_exec passwd "${USER_NAME}"

    rn_echo "请配置 root 的密码..."
    chroot_exec passwd root

    bind_android_gp "${USER_NAME}"
    # 最新archlinux版本需要这个文件
    chroot_exec ln -sf /proc/self/mounts /etc/mtab
    gpg=${LINUX_DIR}/etc/pacman.d/gnupg
    test -d ${gpg} && rm -fr ${gpg}

    # NOTE: You must run `pacman-key --init` before first using pacman; the local
    # keyring can then be populated with the keys of all official Arch Linux ARM
    # packagers with `pacman-key --populate archlinuxarm`.
    # 更新包管理key
    chroot_exec pacman-key --init

    # 解决https证书不存在问题，像curl或是pacman都会使用到，虽然可以通过选项来禁用检查 CAfile: /etc/ssl/certs/ca-certificates.crt
    if [ ! -f "${LINUX_DIR}/etc/ssl/certs/ca-certificates.crt" ]; then
        ln "${LINUX_DIR}/etc/ca-certificates/extracted/tls-ca-bundle.pem" "${LINUX_DIR}/etc/ssl/certs/ca-certificates.crt"
    fi

    linuxStop
    rn_echo "登入linux系统后，使用pacman -Syu升级系统"
    rn_echo '配置完成'
    return 0
}

bind_android_gp() {
    ${DEBUG_ON}
    #安卓必须的权限,choot系统中的用户只有加入这些组中，才能使用像网络之类权限
    android_gp=$(
        cat <<EOF
aid_system:1000
aid_radio:1001
aid_bluetooth:1002
aid_graphics:1003
aid_input:1004
aid_audio:1005
aid_camera:1006
aid_log:1007
aid_compass:1008
aid_mount:1009
aid_wifi:1010
aid_adb:1011
aid_install:1012
aid_media:1013
aid_dhcp:1014
aid_sdcard_rw:1015
aid_vpn:1016
aid_keystore:1017
aid_usb:1018
aid_drm:1019
aid_available:1020
aid_gps:1021
aid_media_rw:1023
aid_mtp:1024
aid_drmrpc:1026
aid_nfc:1027
aid_sdcard_r:1028
aid_clat:1029
aid_loop_radio:1030
aid_media_drm:1031
aid_package_info:1032
aid_sdcard_pics:1033
aid_sdcard_av:1034
aid_sdcard_all:1035
aid_logd:1036
aid_shared_relro:1037
aid_shell:2000
aid_cache:2001
aid_diag:2002
aid_net_bt_admin:3001
aid_net_bt:3002
aid_inet:3003
aid_net_raw:3004
aid_net_admin:3005
aid_net_bw_stats:3006
aid_net_bw_acct:3007
aid_net_bt_stack:3008
EOF
    )

    gp_file="${LINUX_DIR}/etc/group"

    # 复制android必须用户或组到linux；如进程的网络读写权限aid_inet；
    for line in ${android_gp}; do
        if [ -z "${line}" ]; then
            # 若是空行，空字符，跳过
            continue
        fi

        #用:分隔的首一节
        gp_name=$(echo "${line}" | ${BUSY_BOX} awk -F: "{print $1}")
        #用:分隔的后一节
        gid=$(echo "${line}" | ${BUSY_BOX} awk -F: "{print $2}")
        users="${1}"

        if [ "${1}" != "root" ]; then
            # 如果用户不是root，需要把root加入这个特殊组
            users="${users},root"
        fi

        #把已经存在的替换，注意，如果有修改，会丢失,若存在同名组，将被删除，因为不允许同名组存在，android的组id优先
        del_append "${gp_file}" "/^${gp_name}:.*/d" "${gp_name}:x:${gid}:${users}"
    done
}

# 先删行，再追加，再清除空格
del_append() {
    ${DEBUG_ON}
    rn_echo "对 ${1} \n删除 ${2} 后\n再追加 ${3} \n最后删除空行\n..."
    sed -i "${2}" "${1}"
    echo "${3}" >>"${1}"
    sed -i "/^\s*$/d" "${1}"
}

# 检测某分区是否挂载
is_mounted() {
    ${DEBUG_ON}
    mount_point="$1"
    [ -n "$mount_point" ] || return 1
    has=$(grep " ${mount_point%/} " /proc/mounts)

    # 挂载同时也会出现在android系统中，所以使用它来过滤即可
    if [ "${has}" != "" ]; then
        return 0
    else
        return 1
    fi
}

# 失败终止脚本；打印成功信息并继续
fail2die() {
    ${DEBUG_ON}
    exit_code="${?}"

    if [ "${exit_code}" -eq 0 ]; then
        if [ -n "$2" ]; then
            echo "$2"
        fi
        return 0
    fi

    if [ -n "$1" ]; then
        echo "$1"
    fi
    exit 1
}

# 挂载linux需要分区
mountAll() {
    ${DEBUG_ON}

    # 必须要挂载一次，否则pacman无法检测硬盘空间，就不让安装包
    rn_echo "挂载/ ... "
    target="${CHROOT_DIR}"
    if ! is_mounted "$target"; then
        mkdirOrDie "$target"
        ${BUSY_BOX} mount -vvv -o bind "${LINUX_DIR}" "$target" && ${BUSY_BOX} mount -vvv -o remount,exec,suid,dev,rw,relatime "$target"
        fail2die "失败" "成功"
    else
        echo "已存在"
    fi

    rn_echo "挂载/proc ... "
    target="${CHROOT_DIR}/proc"
    if ! is_mounted "$target"; then
        mkdirOrDie "$target"
        ${BUSY_BOX} mount -vvvo rw,nosuid,nodev,noexec,relatime -t proc proc "$target"
        fail2die "失败" "成功"
    else
        echo "已存在"
    fi

    # power kernel firmware block 之类
    rn_echo "挂载/sys ... "
    target="${CHROOT_DIR}/sys"
    if ! is_mounted "$target"; then
        mkdirOrDie "$target"
        ${BUSY_BOX} mount -vvvo rw,nosuid,nodev,noexec,relatime -t sysfs sys "$target"
        fail2die "失败" "成功"
    else
        echo "已存在"
    fi

    rn_echo "挂载/dev ... "
    target="${CHROOT_DIR}/dev"
    if ! is_mounted "$target"; then
        mkdirOrDie "$target"
        ${BUSY_BOX} mount -vvvo bind /dev "$target"
        fail2die "失败" "成功"
    else
        echo "已存在"
    fi

    # ssh之类服务接到client后生成的session,下方就是不存在这目录而登录后卡住
    # debug1: Allocating pty.
    # debug1: session_new: session 0
    # openpty: No such file or directory
    # session_pty_req: session 0 alloc failed

    rn_echo "挂载 /dev/pts ... "
    if ! is_mounted "/dev/pts"; then
        mkdirOrDie "/dev/pts"
        mount -vvvo rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
        fail2die "失败" "成功"
    else
        rn_echo "已存在"
    fi

    target="${CHROOT_DIR}/dev/pts"
    rn_echo "挂载 ${target} ... "

    if ! is_mounted "${target}"; then
        mount -vvvo bind /dev/pts "${target}"
        fail2die "失败" "成功"
    else
        rn_echo "已存在"
    fi

    #    # 共享内存
    #    target="${LINUX_DIR}/dev/shm"

    # /dev/fd -> /proc/self/fd
    # /dev/stderr -> /proc/self/fd/2
    # /dev/stdin -> /proc/self/fd/0
    # /dev/stdout -> /proc/self/fd/1
    #    rn_echo "ln /dev/fd..."

    #    rn_echo "ln /dev/stdin..."
    #    rn_echo "ln /dev/stdout..."
    #    rn_echo "ln /dev/stderr..."
    #    rn_echo "ln /dev/tty ... "

    # 虚拟网卡，vpn之类
    #    rn_echo "挂载/dev/net/tun ... "

    # linux下，类似于windows 以...方式来打开该文件的注册点，比如txt与vim挂上，目前不用gui，用不上
    #        binfmt_dir="/proc/sys/fs/binfmt_misc"

    # 若需要挂载sdcard路径

    if [ -d "${MOUNT_SDCARD_PATH}" ]; then
        path="${MOUNT_SDCARD_PATH}"
        target="${CHROOT_DIR}/root/-"
        rn_echo "挂载${path} ... "
        if ! is_mounted "${target}"; then
            mkdirOrDie "${target}"
            ${BUSY_BOX} mount -vvvo bind "${path}" "${target}" && ${BUSY_BOX} mount -o remount,suid,dev,exec,rw,relatime "${target}"
            fail2die "失败" "成功"
        else
            echo "已存在"
        fi
    else
        echo "sdcard路径不存在或为空，无需挂载处理。"
    fi

    rn_echo
}

# 启动linux
linuxStart() {
    ${DEBUG_ON}
    rn_echo "处理中..."
    mountAll
    echo "准备启动sshd..."
    #启动
    chroot_exec /usr/sbin/sshd -4
    fail2die "失败" "成功"

    if [ -f "${CHROOT_DIR}${RUN_AFTER_START}" ]; then
        rn_echo "尝试执行启动后处理脚本..."
        chroot_exec bash "${RUN_AFTER_START}"
    fi

    rn_echo "使用提示"
    rn_echo "* 若有应用提示没有socket权限，一般原因是需要在/etc/group 此行aid_inet:x:3003:root,mysql加入该用户"
    echo "* 请连接sshd使用linux，比如：127.0.0.1:您设置的端口"
    echo "* 如果curl提示缺少ssl证书，可以使用pacman 安装 ca-certificates-utils"
    echo "* 需要root权限，执行 su 并输入root密码即可，或是安装sudo并配置"
    echo "* 若需要启动后自动执行任务，请编辑${RUN_AFTER_START}"
    echo "* 若需要停止前自动执行任务，请编辑${RUN_BEFORE_STOP}"
    echo "* 保持系统最新，使用 pacman -Suy"
    echo "* 如果遇到pacman提示不信任，可以试试 pacman-key --populate archlinuxarm ，详情见 https://archlinuxarm.org/about/package-signing"
    rn_echo "启动完成,请注意上方提示内容."
}

# 运行linux中程序
chroot_exec() {
    ${DEBUG_ON}
    unset TMP TEMP TMPDIR LD_PRELOAD LD_DEBUG
    path="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    PATH="${path}" chroot "${CHROOT_DIR}" "${@}"
}

# 停止linux
linuxStop() {
    ${DEBUG_ON}
    
    if ! is_mounted "${CHROOT_DIR}"; then
        rn_echo "未开启不需要处理"
        return 0
    fi
    
    rn_echo "开始处理... "
    
    # 不能使用linux dir 因为可能未挂载
    if [ -f "${CHROOT_DIR}${RUN_BEFORE_STOP}" ]; then
        rn_echo "尝试执行停止前处理脚本..."
        chroot_exec bash "${RUN_BEFORE_STOP}"
    fi

    echo "尝试结束所有进程..."
    # 判断lsof输出格式
    lsof_full=$(lsof | ${BUSY_BOX} awk "{print \$1}" | grep -c '^lsof')

    # 直到所有进程都结束了
    while true; do

        # lsof显示首列不同，使用不同列举方法
        # 如grep或是lsof都是属于运行完就结束了，也会出现在列表中，这个目录有启动时所在的目录或是主动打开的，所以一个pid可能拥有多条记录
        if [ "$lsof_full" -eq 0 ]; then
            pids=$(lsof | grep "${CHROOT_DIR%/}" | $BUSY_BOX awk "{print \$1}" | uniq)
        else
            pids=$(lsof | grep "${CHROOT_DIR%/}" | $BUSY_BOX awk "{print \$2}" | uniq)
        fi

        if [ -z "${pids}" ]; then
            break
        fi

        kill_pids "${pids}"
    done

    rn_echo "全部进程已终止"
    echo "卸载分区... "
    mnt_count=0

    for root_dir in "${CHROOT_DIR}" "${LINUX_DIR}"; do
        # 因为存在bind后再remount,所以要多次操作直到没有任何mount
        while true; do
            # 按长到短顺序排序，先卸载长的
            parts=$($BUSY_BOX awk "{print \$2}" /proc/mounts | grep "^${root_dir%/}" | sort -ur)

            if [ -z "${parts}" ]; then
                # 没有了
                break
            fi

            # shellcheck disable=SC2059
            printf "待卸载列表：\n${parts}\n"
            part=""

            for part in $parts; do
                part_name=$(echo "${part}" | sed "s|^${root_dir%/}/*|/|g")
                rn_echo "准备卸载分区${part_name} ... "

                for i in 1 2 3 4 5 6 7 8 9 10; do
                    $BUSY_BOX umount -vvv -f "${part}" && echo "第 ${i} 次尝试操作成功" && break
                    sleep 1s
                done

                mnt_count=$((mnt_count + 1))

            done

        done
    done

    if [ "${mnt_count}" -eq "0" ]; then
        rn_echo "未挂载分区"
    fi

    echo "停止完成"
}

# 结束所有linux进程
kill_pids() {
    ${DEBUG_ON}
    pids=$(get_pids "${@}")

    if [ -n "${pids}" ]; then
        ps_ids=""
        kl_ids=""

        # posix sh 不支持${var// /,}替换用法，这里使用for来处理
        for i in ${pids}; do
            if [ "${ps_ids}" = "" ]; then
                ps_split=""
                kl_split=""
            else
                ps_split=","
                kl_split=" "
            fi

            ps_ids="${ps_ids}${ps_split}${i}"
            kl_ids="${kl_ids}${kl_split}${i}"

        done

        echo "kill -9 以下进程..."
        ps -l -p "${ps_ids}"
        # 本来应该无双引号，idea 却有bug的提示要加
        kill9="kill -9 ${kl_ids}"
        ${kill9}
    fi

    return 0
}

# 获取linux进程
get_pids() {
    ${DEBUG_ON}
    pids=""

    # shellcheck disable=SC2048
    for pid in $*; do
        if [ -z "${pid}" ]; then
            continue
        fi

        if [ -e "/proc/$pid" ]; then
            pids="${pids} ${pid}"
        fi
    done

    echo "${pids}"
    return 0
}

# 检测android是否启用selinux
selinux_inactive() {
    ${DEBUG_ON}
    if [ -e "/sys/fs/selinux/enforce" ]; then
        return "$(cat /sys/fs/selinux/enforce)"
    else
        return 0
    fi
}

# 检测android是否支持loop
loop_support() {
    ${DEBUG_ON}
    losetup -f
    return $?
}

multiarch_support() {
    ${DEBUG_ON}
    if [ -d "/proc/sys/fs/binfmt_misc" ]; then
        return 0
    else
        return 1
    fi
}

chroot_shell() {
    ${DEBUG_ON}
    linuxStart
    rn_echo "初始化成功"
    chroot_exec /bin/bash
}

#awk 取第2节实现
awk2() {
    ${DEBUG_ON}
    # 多个空格替换成单个
    input=$(echo "${*}" | sed "s/ +/ /g")
    input=${input#* }
    input=${input%% *}
    # shellcheck disable=SC2059
    printf "${input}"
}

# 查看linux当前状态
linuxStatus() {
    ${DEBUG_ON}
    rn_echo '整理状态信息...'
    model=$(command -v getprop >/dev/null && getprop ro.product.model)

    if [ -n "$model" ]; then
        echo "设备:$model"
    fi

    android=$(command -v getprop >/dev/null && getprop ro.build.version.release)
    if [ -n "$android" ]; then
        echo "Android 版本: $android"
    fi

    echo "处理器内核:$(uname -m)"
    echo "android内核: $(uname -r)"
    rn_echo "环境变量：\n $(env)\n\n"
    mem_total=$(awk2 "$(grep ^MemTotal /proc/meminfo)")
    # POSIX sh 只支持这种方式
    mem_total=$((mem_total / 1024 / 1024))
    mem_free=$(grep ^MemAvailable /proc/meminfo)
    mem_free=${mem_free#* }
    mem_free=${mem_free% *}
    mem_free=$((mem_free / 1024 / 1024))
    echo "可用/总内存：$mem_free/$mem_total GB"
    swap_total=$(grep ^SwapTotal /proc/meminfo)
    swap_total=${swap_total#* }
    swap_total=${swap_total% *}
    swap_total=$((swap_total / 1024))
    swap_free=$(grep ^SwapFree /proc/meminfo)
    swap_free=${swap_free#* }
    swap_free=${swap_free% *}
    swap_free=$((swap_free / 1024))
    echo "可用/总交换空间：$swap_free/$swap_total MB"

    (selinux_inactive && echo "SELinux 未启用") || echo "SELinux 已启用"

    (loop_support && echo "Loop devices: 支持") || echo "Loop devices:不支持"

    supported_fs=$(printf '%s ' "$(grep -v nodev /proc/filesystems | sort)")
    echo "支持文件系统：$supported_fs"
    release=$(cat "${LINUX_DIR}/etc/arch-release")
    echo "安装的linux：${release}"

    is_mnt=0

    for item in $(awk2 "$(grep "${CHROOT_DIR%/}" /proc/mounts)" | sed "s|${CHROOT_DIR%/}/*|/|g"); do
        echo "已挂载的linux分区: $item"
        is_mnt=1
    done

    [ "$is_mnt" -ne "1" ] && echo "未挂载linux分区"

    is_mountpoints=0

    for mp in $(grep -v "${CHROOT_DIR%/}" /proc/mounts | grep ^/ | $BUSY_BOX awk "{print \$2\":\"\$3}"); do
        part=$(echo "$mp" | $BUSY_BOX awk -F: "{print \$1}")
        fstype=$(echo "$mp" | $BUSY_BOX awk -F: "{print \$2}")
        block_size=$(stat -c '%s' -f "$part")
        available=$(stat -c '%a' -f "$part" | $BUSY_BOX awk "{printf(\"%.1f\",\$1*${block_size}/1024/1024/1024)}")
        total=$(stat -c '%b' -f "$part" | $BUSY_BOX awk "{printf(\"%.1f\",\$1*${block_size}/1024/1024/1024)}")
        if [ -n "$available" ] && [ -n "$total" ]; then
            echo "android挂载点 $part  $available/$total GB ($fstype)"
            is_mountpoints=1
        fi
    done
    [ "$is_mountpoints" -ne 1 ] && echo "android未挂载"

    is_partitions=0

    for dev in /sys/block/*/dev; do
        if [ -f "$dev" ]; then
            devname=$(echo "$dev" | sed -e 's@/dev@@' -e 's@.*/@@')
            [ -e "/dev/$devname" ] && devpath="/dev/$devname"
            [ -e "/dev/block/$devname" ] && devpath="/dev/block/$devname"
            [ -n "$devpath" ] && parts=$(fdisk -l "$devpath" 2>/dev/null | grep ^/dev/ | $BUSY_BOX awk "{print \$1}")

            for part in $parts; do
                size=$(fdisk -l "$part" 2>/dev/null | grep 'Disk.*bytes' | $BUSY_BOX awk "{ sub(/,/,""); print \$3\" \"\$4}")
                type=$(fdisk -l "$devpath" 2>/dev/null | grep "^${part}" | tr -d '*' | $BUSY_BOX awk "{str=\$6; for (i=7;i<=10;i++) if (\$i!=\"\") str=str\" \"\$i; printf(\"%s\",str)}")
                echo " $part  $size ($type)"
                is_partitions=1
            done
        fi
    done
    [ "$is_partitions" -ne 1 ] && echo " ...没有可用用户分区"

    echo '操作完成'
}

die() {
    ${DEBUG_ON}
    if [ "0" -ne "$1" ]; then
        if [ -n "$2" ]; then
            echo "$2"
        fi
        exit "$1"
    fi
}

# 目录不存在将创建
mkdirOrDie() {
    ${DEBUG_ON}
    if [ -d "$1" ]; then
        return 0
    fi

    mkdir -p "$1"
    die $? "创建目录 $1 失败"
}

# 自动更新脚本
update() {
    ${DEBUG_ON}
    end_tag="###DOWNLOAD.EOF###"
    echo "检查新版本..."
    last=$(curl -vvv -l "${LAST_URL}")

    if [ "${last}" = "${VER}" ]; then
        rn_echo "已是最新版本"
        return 0
    elif [ "${last}" -gt "${VER}" ]; then
        ${DEBUG_OFF}
        rn_echo "发现新版本：${last}，立刻升级请输入大写 Y："
        read -r yes
        ${DEBUG_ON}

        if [ "${yes}" != "Y" ]; then
            echo "放弃处理升级"
            return 0
        fi

        dl="${SH_PATH}.dl"
        echo "开始下载新版本..."
        echo "从 ${SRC_URL} 保存到 ${dl} "
        curl -vvv -lo "${dl}" "${SRC_URL}"
        exit_code="${?}"

        if [ "${exit_code}" -ne "0" ]; then
            printf "\n\n下载出错,请重启脚本后再试"
            return 1
        fi

        chmod a+rw "${dl}"
        has=$(grep "${end_tag}" "${dl}")

        if [ "${has}" = "" ]; then
            cat "${dl}"
            printf "\n\n\n\n文件下载有误，请重试。内容如上"
            return 1
        fi

        mv -f "${dl}" "${SH_PATH}"
        sh "${DEBUG_SH}" "${SH_PATH}"
        exit 0
    else
        rn_echo "无法检查新版本"
    fi
}

rn_echo() {
    ${DEBUG_ON}
    # shellcheck disable=SC2059
    printf "\n\n${1}\n"
}

pause_tip() {
    ${DEBUG_OFF}
    echo "回车键退出，暂停中..."
    # 防止idea提示
    read -r tmp || test "${tmp}"
    ${DEBUG_ON}
}

############ 限制 只能指定设备使用本脚本 ###################
# 因为sh不支持 set -T,所以要在每个funciton的首行放

# 见help set说明

# 禁用调试
DEBUG_ON=""
DEBUG_OFF=""
DEBUG_SH=""

case "${-}" in
*"x"*)
    # 开启调试
    DEBUG_ON="set -x -e"
    DEBUG_OFF="set +x +e"
    DEBUG_SH="-x -e"
    ;;
esac

${DEBUG_ON}

dev_m=$(uname -m)

if [ "${dev_m}" != "armv8" ] && [ "${dev_m}" != "aarch64" ]; then
    echo "脚本只支持 armv8版本cpu；当前系统构架是：${dev_m}"
    exit 1
fi

uid=$(id -u)
ROOT_UID=0
SH_PATH=$(realpath "${0}")

# 如果不是root，尝试切换成su模式
if [ "${uid}" -ne "${ROOT_UID}" ]; then
    if [ ! -f "${SU_PATH}" ]; then
        echo "su文件 ${SU_PATH}  不存在"
        exit 1
    fi

    if [ ! -x "${SU_PATH}" ]; then
        echo "无权执行su文件 ${SU_PATH}，可能是未给本应用root授权"
        exit 1
    fi

    if [ "$(stat -c %u ${SU_PATH})" -ne "${ROOT_UID}" ]; then
        echo "su文件 ${SU_PATH}，不正确，非root级命令"
        exit 1
    fi

    #切换成root
    su -c "sh ${DEBUG_SH} \"${SH_PATH}\"" && exit 0

    rn_echo "切换到root模式运行本脚本操作出错"
    # 必须退出当前的
    exit 0
fi

umask 0022
unset LANG
mkdirOrDie "${CHROOT_DIR}"
mkdirOrDie "${LINUX_DIR}"
mkdirOrDie "$(dirname ${BUSY_BOX})"

if [ ! -f "${BUSY_BOX}" ]; then
    echo "busybox正在下载..."
    curl -vvvlo "${BUSY_BOX}" "${BUSY_BOX_URL}"
    fail2die "下载busybox失败" "下载成功"
fi

if [ ! -x "${BUSY_BOX}" ]; then
    echo "赋予 ${BUSY_BOX} 可执行权限..."
    chmod a+rx "${BUSY_BOX}"
    fail2die "操作失败，请重试"
fi

# 这个选择不显示调试信息
${DEBUG_OFF}
printf "\n\n\n\n"
echo "1） 启动linux"
echo "2） 停止linux"
echo "3） 重新部署linux"
echo "4） 重新配置linux"
echo "5） 查看linux当前状态"
echo "6)  chroot shell"
echo "7） 重启手机"
echo "8） 升级脚本"
echo ""
echo "请输入上方数字选择相应操作："
read -r num

${DEBUG_ON}

case "$num" in
1)
    linuxStart
    pause_tip
    ;;
2)
    linuxStop
    pause_tip
    ;;
3)
    linuxDeploy
    pause_tip
    ;;
4)
    linuxConfig
    pause_tip
    ;;
5)
    linuxStatus
    pause_tip
    ;;
6)
    chroot_shell
    pause_tip
    ;;
7)
    ${DEBUG_OFF}
    rn_echo "确认要重启吗（按ctrl+c中止）？"
    # 防止idea提示
    read -r tmp || test "${tmp}"
    ${DEBUG_ON}
    reboot
    ;;
8)
    update
    pause_tip
    ;;
esac

exit 0

# 特殊标志，给升级判断完整性用,所有代码必须写在上方
###DOWNLOAD.EOF###

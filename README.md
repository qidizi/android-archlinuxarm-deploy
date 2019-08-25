# android-archlinuxarm-deploy
安卓archlinuxarm部署脚本

## 依赖

1. 手机已root   

---
## 使用方法见下方相应说明


1.  [小米9+android Q,请使用此脚本，使用方法见脚本前面注释](archlinux-for-mi9-q.sh)   

---
## 一些问题


1.  在android手机上使用linux大概原理有chroot（需要root），proot（不需要root，比较出名的见 [termux](https://github.com/termux/termux-app) ),还有像fakechroot，
但是只有chroot的支持最好，见 [ArchLinux chroot Wiki](https://wiki.archlinux.org/index.php/Chroot_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87))  
1.  关于linux发行版本选择。我尝试过Debian、ubuntu、Fedora、centos、archlinux，最后选择了archlinux，因为它有arm树莓派分支，支持是最好的；且在android上只是为了有时方便能做点linux事情，并不是试用linux，维护1种即可；
1.  如果termux已经满足您的使用，你大可不必使用本方案；   
1.  本脚本首先是满足自用，在使用过程发现bug会fix，因此脚本兼容性并一定满足所有手机，但是我会尽量注释和保持一个脚本即可完成所有操作；   

--

感谢： https://github.com/meefik/linuxdeploy-cli
---
## 缩略图

![获取部署脚本](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/get-sh.jpeg)  

![执行部署脚本](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/sh.jpeg)   

![pc通过ssh登录android linux](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/pc.png)   

![手机上登录android linux](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/ssh.jpeg)   


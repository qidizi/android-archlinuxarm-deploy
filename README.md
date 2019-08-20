# android-archlinuxarm-deploy
安卓archlinuxarm部署脚本

---
原理参考、部分代码直接摘之：https://github.com/meefik/linuxdeploy-cli

---
## 依赖


1. 手机必须已root，必须  
1. cpu是aarch64，其它构架自行修改脚本也可使用；  

---
## 使用方法


1.  手机root；  
1.  安装ssh客户端，推荐 termius；并授权此app具有root权限；  
1.  在termius中创建协议为local的主机，例如别名叫mi；  
1.  在输入法加入如下命令作为快速输入，如qq输入法的快捷短语、百度的懒人短语、搜狗的快捷短语：`curl -v -o ${EXTERNAL_STORAGE}/linux-deploy.sh https://raw.githubusercontent.com/qidizi/android-archlinuxarm-deploy/master/deploy.sh && /system/bin/sh ${EXTERNAL_STORAGE}/linux-deploy.sh`,最新使用建议见deploy.sh注释；这个命令意思是每次都先下载，再执行它;本脚本是针对android自带的sh编写,像termux 的sh运行时就会提示语法错误；  
1.  根据命令提示操作；  

---
## 关于本脚本


1.  虽然google play提供了一个linux-deploy app，但是我更想了解部署原理，于是这个脚本出现了；   
1.  我尝试过Debian、ubuntu、Fedora、centos、archlinux，最后选择了archlinux，因为它有arm树莓派分支，支持是最好的；且在android上只是为了有时方便能做点linux事情，并不是试用linux，维护种即可；   
1.  本脚本首先是满足自用，所以，会根据需要随时调整，若有需要参考者，请fork后维护使用；   

---
## 缩略图

![获取部署脚本](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/get-sh.jpeg)  

![执行部署脚本](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/sh.jpeg)   

![pc通过ssh登录android linux](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/pc.png)   

![手机上登录android linux](https://github.com/qidizi/android-archlinuxarm-deploy/raw/master/ssh.jpeg)   





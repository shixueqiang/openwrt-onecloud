#!/bin/bash

# kenrel Vermagic
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk
grep HASH include/kernel-6.12 | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}' > .vermagic



function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../
  cd .. && rm -rf $repodir
}


git_sparse_clone master https://github.com/openwrt/packages lang/golang
git_sparse_clone master https://github.com/openwrt/packages net/uwsgi
git_sparse_clone master https://github.com/openwrt/openwrt package/kernel/ubnt-ledbar
git_sparse_clone master https://github.com/openwrt/openwrt package/kernel/cryptodev-linux

git clone https://github.com/sbwml/autocore-arm package/autocore-arm -b "$REPO_BRANCH" --depth 1

rm -rf package/autocore-arm/.git

git clone -b base-23.05 --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/base-23.05
git clone -b packages --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/xd
git clone -b porxy --depth 1 --single-branch https://github.com/shiyu1314/openwrt-feeds package/porxy


rm -rf package/kernel/{ubnt-ledbar,cryptodev-linux}
rm -rf feeds/packages/lang/golang
rm -rf feeds/luci/applications/{luci-app-dockerman,luci-app-firewall,luci-app-samba4,luci-app-aria2}
rm -rf package/libs/{libnftnl,libunwind}
rm -rf package/network/{utils/nftables,iproute2,config/firewall4}
rm -rf feeds/packages/libs/{nghttp3,ngtcp2,zlib}
rm -rf feeds/packages/{net/samba4,v2ray-geodata,mosdns,sing-box,uwsgi,curl,aria2,ariang,libs/liburing,adguardhome}
rm -f feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/29_ports.js


cp -rf {ubnt-ledbar,cryptodev-linux} package/kernel
cp -rf golang feeds/packages/lang
cp -rf uwsgi feeds/packages/net


# luci - fix compat translation
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm

pushd feeds/luci
    patch -p1 < 0001-luci-mod-network-add-option-for-ipv6-max-plt-vlt.patch
    patch -p1 < 0001-luci-mod-system-add-modal-overlay-dialog-to-reboot.patch
    patch -p1 < 0002-luci-mod-status-displays-actual-process-memory-usage.patch
    patch -p1 < 0003-luci-mod-status-storage-index-applicable-only-to-val.patch
    patch -p1 < 0004-luci-mod-status-firewall-disable-legacy-firewall-rul.patch
    patch -p1 < 0005-luci-mod-system-add-refresh-interval-setting.patch
    patch -p1 < 0006-luci-mod-system-mounts-add-docker-directory-mount-po.patch
    patch -p1 < 0007-luci-base-correct-textarea-wrap.patch
    patch -p1 < 0008-luci-base-cbifileupload-support-file-browser-mode.patch
    patch -p1 < 0009-luci-base-fix-table-option-does-not-show-with-depends.patch
popd

sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd-mod-ubus //' feeds/luci/collections/luci/Makefile
sed -i 's/+uhttpd /+luci-nginx /g' feeds/luci/collections/luci-light/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl-openssl/Makefile
sed -i "s/+luci /+luci-nginx /g" feeds/luci/collections/luci-ssl/Makefile
sed -i 's/+uhttpd +uhttpd-mod-ubus /+luci-nginx /g' feeds/packages/net/wg-installer/Makefile
sed -i '/uhttpd-mod-ubus/d' feeds/luci/collections/luci-light/Makefile
sed -i 's/+luci-nginx \\$/+luci-nginx/' feeds/luci/collections/luci-light/Makefile

# nginx-util - fix gcc13
if [ "$REPO_BRANCH" = "openwrt-23.05" ]; then
    pushd feeds/packages
        patch -p1 < 0001-nginx-util-fix-compilation-with-GCC13.patch
        patch -p1 < 0002-nginx-util-move-to-pcre2.patch
    popd
fi


# nginx - latest version
rm -rf feeds/packages/net/nginx
git clone https://github.com/sbwml/feeds_packages_net_nginx feeds/packages/net/nginx -b "$REPO_BRANCH"
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g;s/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/net/nginx/files/nginx.init

# nginx - ubus
sed -i 's/ubus_parallel_req 2/ubus_parallel_req 6/g' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 300;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support

# uwsgi - fix timeout
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i '/limit-as/c\limit-as = 5000' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# disable error log
sed -i "s/procd_set_param stderr 1/procd_set_param stderr 0/g" feeds/packages/net/uwsgi/files/uwsgi.init

# uwsgi - performance
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini

# rpcd - fix timeout
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js



# openssl urandom
sed -i "/-openwrt/iOPENSSL_OPTIONS += enable-ktls '-DDEVRANDOM=\"\\\\\"/dev/urandom\\\\\"\"\'\n" package/libs/openssl/Makefile


# fix kernel-6.x
# kernel: enable Multi-Path TCP
if [ "$REPO_BRANCH" = "openwrt-23.05" ]; then
    patch -p1 < 0010-include-kernel-add-config-for-linux-6.x.patch
    patch -p1 < 0014-kernel-enable-Multi-Path-TCP-for-SMALL_FLASH-targets.patch
fi



./scripts/feeds update -a
./scripts/feeds install -a


sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

sudo rm -rf package/base-files/files/etc/banner

sed -i "s/%D %V %C/%D %V $(TZ=UTC-8 date +%Y.%m.%d)/" package/base-files/files/etc/openwrt_release

sed -i "s/%R/by $OP_author/" package/base-files/files/etc/openwrt_release

date=$(date +"%Y-%m-%d")
echo "                                                    " >> package/base-files/files/etc/banner
echo "  _______                     ________        __" >> package/base-files/files/etc/banner
echo " |       |.-----.-----.-----.|  |  |  |.----.|  |_" >> package/base-files/files/etc/banner
echo " |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|" >> package/base-files/files/etc/banner
echo " |_______||   __|_____|__|__||________||__|  |____|" >> package/base-files/files/etc/banner
echo "          |__|" >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner
echo "         %D ${date} by $OP_author                     " >> package/base-files/files/etc/banner
echo " -----------------------------------------------------" >> package/base-files/files/etc/banner

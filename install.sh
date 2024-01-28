#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# kiểm tra quyền root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Script này phải được chạy với quyền người dùng root!\n" && exit 1

# kiểm tra hệ điều hành
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
    echo -e "${red}Script không hỗ trợ hệ điều hành alpine!${plain}\n" && exit 1
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}Không thể xác định phiên bản hệ điều hành, vui lòng liên hệ với tác giả script!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Không thể xác định kiến trúc, sử dụng kiến trúc mặc định: ${arch}${plain}"
fi

echo "Kiến trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm không hỗ trợ hệ thống 32 bit (x86), vui lòng sử dụng hệ thống 64 bit (x86_64), nếu có lỗi xác định, vui lòng liên hệ tác giả"
    exit 2
fi

# phiên bản hệ điều hành
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Lưu ý: CentOS 7 không thể sử dụng giao thức hysteria1/2!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
        yum install ca-certificates wget -y
        update-ca-trust force-enable
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
        apt-get install ca-certificates wget -y
        update-ca-certificates
    fi
}

# 0: đang chạy, 1: không chạy, 2: không cài đặt
check_status() {
    if [[ ! -f /etc/systemd/system/Aiko-Server.service ]]; then
        return 2
    fi
    temp=$(systemctl status Aiko-Server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_Aiko-Server() {
    if [[ -e /usr/local/Aiko-Server/ ]]; then
        rm -rf /usr/local/Aiko-Server/
    fi

    mkdir /usr/local/Aiko-Server/ -p
    cd /usr/local/Aiko-Server/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/Github-Aiko/Aiko-Server/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể kiểm tra phiên bản mới nhất của Aiko-Server, có thể bạn đã vượt quá giới hạn API của Github, vui lòng thử lại sau hoặc cài đặt phiên bản cụ thể của Aiko-Server${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của Aiko-Server: ${last_version}, bắt đầu cài đặt"
        wget -q -N --no-check-certificate -O /usr/local/Aiko-Server/Aiko-Server-linux.zip https://github.com/Github-Aiko/Aiko-Server/releases/download/${last_version}/Aiko-Server-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống Aiko-Server thất bại, hãy chắc chắn rằng máy chủ của bạn có thể tải xuống tệp từ Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Github-Aiko/Aiko-Server/releases/download/${last_version}/Aiko-Server-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt Aiko-Server $1"
        wget -q -N --no-check-certificate -O /usr/local/Aiko-Server/Aiko-Server-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống Aiko-Server $1 thất bại, hãy chắc chắn phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip Aiko-Server-linux.zip
    rm Aiko-Server-linux.zip -f
    chmod +x Aiko-Server
    mkdir /etc/Aiko-Server/ -p
    rm /etc/systemd/system/Aiko-Server.service -f
    file="https://github.com/Github-Aiko/AikoServer-script/raw/master/Aiko-Server.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/Aiko-Server.service ${file}
    systemctl daemon-reload
    systemctl stop Aiko-Server
    systemctl enable Aiko-Server
    echo -e "${green}Aiko-Server ${last_version}${plain} đã được cài đặt xong và cấu hình để khởi động cùng hệ thống"
    cp geoip.dat /etc/Aiko-Server/
    cp geosite.dat /etc/Aiko-Server/

    if [[ ! -f /etc/Aiko-Server/config.json ]]; then
        cp config.json /etc/Aiko-Server/
        echo -e ""
        echo -e "Đây là lần cài đặt đầu tiên, xin hãy tham khảo hướng dẫn tại: https://github.com/Github-Aiko/Aiko-Server/tree/master/example để cấu hình các thông số cần thiết"
        first_install=true
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server đã được khởi động lại thành công${plain}"
        else
            echo -e "${red}Aiko-Server có thể khởi động thất bại, vui lòng kiểm tra thông tin chi tiết trong nhật ký sau vài phút, nếu không thể khởi động có thể do thay đổi định dạng cấu hình, xem thêm tại wiki: https://github.com/Aiko-Server-project/Aiko-Server/wiki${plain}"
        fi
        first_install=false
    fi

    if [[ ! -f /etc/Aiko-Server/dns.json ]]; then
        cp dns.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/route.json ]]; then
        cp route.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Aiko-Server/
    fi
    if [[ ! -f /etc/Aiko-Server/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/Aiko-Server/
    fi
    curl -o /usr/bin/Aiko-Server -Ls https://raw.githubusercontent.com/Github-Aiko/AikoServer-script/master/Aiko-Server.sh
    chmod +x /usr/bin/Aiko-Server
    if [ ! -L /usr/bin/Aiko-Server ]; then
        ln -s /usr/bin/Aiko-Server /usr/bin/Aiko-Server
        chmod +x /usr/bin/Aiko-Server
    fi
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Hướng dẫn sử dụng script quản lý Aiko-Server (tương thích với việc sử dụng Aiko-Server để thực thi, không phân biệt chữ hoa chữ thường): "
    echo "------------------------------------------"
    echo "Aiko-Server              - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo "Aiko-Server start        - Khởi động Aiko-Server"
    echo "Aiko-Server stop         - Dừng Aiko-Server"
    echo "Aiko-Server restart      - Khởi động lại Aiko-Server"
    echo "Aiko-Server status       - Kiểm tra trạng thái của Aiko-Server"
    echo "Aiko-Server enable       - Cài đặt khởi động tự động Aiko-Server khi máy tính bật"
    echo "Aiko-Server disable      - Hủy cài đặt khởi động tự động Aiko-Server"
    echo "Aiko-Server log          - Xem nhật ký của Aiko-Server"
    echo "Aiko-Server x25519       - Tạo khóa x25519"
    echo "Aiko-Server generate     - Tạo file cấu hình cho Aiko-Server"
    echo "Aiko-Server update       - Cập nhật Aiko-Server"
    echo "Aiko-Server update x.x.x - Cập nhật phiên bản xác định của Aiko-Server"
    echo "Aiko-Server install      - Cài đặt Aiko-Server"
    echo "Aiko-Server uninstall    - Gỡ cài đặt Aiko-Server"
    echo "Aiko-Server version      - Kiểm tra phiên bản của Aiko-Server"
    echo "------------------------------------------"
    # Nếu là lần cài đặt đầu tiên, hỏi người dùng có muốn tự động tạo file cấu hình không
    if [[ $first_install == true ]]; then
        read -rp "Đây là lần đầu tiên bạn cài đặt Aiko-Server, bạn có muốn tự động tạo file cấu hình không? (y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls https://raw.githubusercontent.com/Github-Aiko/AikoServer-script/master/initconfig.sh
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
            read -rp "Bạn có muốn cài đặt bbr kernel không? (y/n): " if_install_bbr
            if [[ $if_install_bbr == [Yy] ]]; then
                install_bbr
            fi
        fi
    fi
}


echo -e "${green}Bắt đầu cài đặt${plain}"
install_base
install_Aiko-Server $1

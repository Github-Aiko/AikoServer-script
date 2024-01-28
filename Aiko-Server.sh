#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
    echo -e "${red}Kịch bản không hỗ trợ hệ thống Alpine trong thời điểm này!${plain}\n" && exit 1
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
    echo -e "${red}Nếu phiên bản hệ thống không được phát hiện, xin vui lòng liên hệ với tác giả tập lệnh!${plain}\n" && exit 1
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng phiên bản hệ thống 7 trở lên của hệ thống!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Lưu ý: Centos 7 không thể sử dụng giao thức hysteria1/2!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng hệ thống phiên bản Ubuntu 16 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng phiên bản Debian 8 trở lên của hệ thống!${plain}\n" && exit 1
    fi
fi

# 检查系统是否有 IPv6 地址
check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"  # 支持 IPv6
    else
        echo "0"  # 不支持 IPv6
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启Aiko-Server" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn xe và quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/AikoServer-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản được chỉ định (phiên bản mới nhất mặc định): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/Github-Aiko/AikoServer-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Quá trình cập nhật đã hoàn tất và Aiko-Server đã được tự động khởi động lại. Vui lòng sử dụng nhật ký Aiko-Server để xem nhật ký hoạt động. ${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Aiko-Server sẽ tự động khởi động lại sau khi sửa đổi cấu hình"
    vi /etc/Aiko-Server/aiko.json
    sleep 2
    restart
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko-Server: ${green}Đang chạy${plain}"
            ;;
        1)
            echo -e "Có vẻ như bạn chưa khởi động Aiko-Server hoặc việc tự động khởi động lại Aiko-Server đã thất bại. Bạn có muốn xem logs không? [Y/n]" && echo
            read -e -rp "(Mặc định: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng thái Aiko-Server: ${red}Chưa cài đặt${plain}"
    esac
}


start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko-Server đã đang chạy, không cần khởi động lại. Để khởi động lại, vui lòng chọn tùy chọn 'restart'${plain}"
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server đã khởi động thành công. Vui lòng sử dụng Aiko-Server log để xem nhật ký hoạt động${plain}"
        else
            echo -e "${red}Có thể Aiko-Server không khởi động thành công. Vui lòng kiểm tra lại sau bằng lệnh 'Aiko-Server log' để xem thông tin nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko-Server đã đang chạy, không cần khởi động lại. Để khởi động lại, vui lòng chọn tùy chọn 'restart'${plain}"
    else
        systemctl start Aiko-Server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko-Server đã được khởi động thành công. Vui lòng sử dụng Aiko-Server log để xem nhật ký hoạt động${plain}"
        else
            echo -e "${red}Có thể Aiko-Server không khởi động thành công. Vui lòng kiểm tra lại sau bằng lệnh 'Aiko-Server log' để xem thông tin nhật ký${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Aiko-Server
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Aiko-Server đã dừng thành công${plain}"
    else
        echo -e "${red}Dừng Aiko-Server thất bại, có thể là do quá trình dừng mất quá 2 giây. Vui lòng kiểm tra logs sau để biết thêm thông tin${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


restart() {
    systemctl restart Aiko-Server
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã được khởi động lại thành công. Vui lòng sử dụng Aiko-Server log để xem nhật ký hoạt động${plain}"
    else
        echo -e "${red}Có thể Aiko-Server không khởi động lại thành công. Vui lòng kiểm tra lại sau bằng lệnh 'Aiko-Server log' để xem thông tin nhật ký${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


status() {
    systemctl status Aiko-Server --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã được thiết lập tự động khởi động cùng với hệ thống thành công${plain}"
    else
        echo -e "${red}Aiko-Server thiết lập tự động khởi động cùng với hệ thống thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Aiko-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko-Server đã được tắt chế độ tự động khởi động cùng với hệ thống thành công${plain}"
    else
        echo -e "${red}Aiko-Server tắt chế độ tự động khởi động cùng với hệ thống thất bại${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Aiko-Server.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh)
}

update_shell() {
    wget -O /usr/bin/Aiko-Server -N --no-check-certificate https://raw.githubusercontent.com/Github-Aiko/AikoServer-script/master/Aiko-Server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Tải xuống tập lệnh thất bại. Vui lòng kiểm tra kết nối của máy tính với Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Aiko-Server
        echo -e "${green}Nâng cấp tập lệnh thành công. Vui lòng chạy lại tập lệnh${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
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

check_enabled() {
    temp=$(systemctl is-enabled Aiko-Server)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Aiko-server đã được cài đặt, vui lòng không lặp lại cài đặt${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt máy chủ aiko trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko-Server: ${green}Đang chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái Aiko-Server: ${yellow}Không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái Aiko-Server: ${red}Chưa cài đặt${plain}"
    esac
}


show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự động khởi động cùng với hệ thống: ${green}Có${plain}"
    else
        echo -e "Tự động khởi động cùng với hệ thống: ${red}Không${plain}"
    fi
}


generate_x25519_key() {
    echo -n "Đang tạo khóa x25519: "
    /usr/local/Aiko-Server/Aiko-Server x25519
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


show_Aiko-Server_version() {
    echo -n "Phiên bản Aiko-Server: "
    /usr/local/Aiko-Server/Aiko-Server version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


add_node_config() {
    echo -e "${green}Vui lòng chọn loại nhân cốt của nút:${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    read -rp "Nhập lựa chọn của bạn: " core_type
    if [ "$core_type" == "1" ]; then
        core="xray"
        core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"
        core_sing=true
    else
        echo "Lựa chọn không hợp lệ. Vui lòng chọn 1 hoặc 2."
        continue
    fi
    while true; do
        read -rp "Nhập Node ID của nút: " NodeID
        # Kiểm tra NodeID có phải là số nguyên dương hay không
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # Nhập đúng, thoát khỏi vòng lặp
        else
            echo "Lỗi: Vui lòng nhập số nguyên dương làm Node ID."
        fi
    done
    
    echo -e "${yellow}Vui lòng chọn giao thức truyền tải cho nút:${plain}"
    echo -e "${green}1. Shadowsocks${plain}"
    echo -e "${green}2. Vless${plain}"
    echo -e "${green}3. Vmess${plain}"
    echo -e "${green}4. Hysteria${plain}"
    echo -e "${green}5. Hysteria2${plain}"
    echo -e "${green}6. Tuic${plain}"
    echo -e "${green}7. Trojan${plain}"
    read -rp "Nhập lựa chọn của bạn: " NodeType
    case "$NodeType" in
        1 ) NodeType="shadowsocks" ;;
        2 ) NodeType="vless" ;;
        3 ) NodeType="vmess" ;;
        4 ) NodeType="hysteria" ;;
        5 ) NodeType="hysteria2" ;;
        6 ) NodeType="tuic" ;;
        7 ) NodeType="trojan" ;;
        * ) NodeType="shadowsocks" ;;
    esac
    if [ $NodeType == "vless" ]; then
        read -rp "Chọn liệu đây có phải là nút reality không? (y/n)" isreality
    fi
    certmode="none"
    certdomain="example.com"
    if [ "$isreality" != "y" ] && [ "$isreality" != "Y" ]; then
        read -rp "Chọn liệu bạn muốn cấu hình TLS không? (y/n)" istls
        if [ "$istls" == "y" ] || [ "$istls" == "Y" ]; then
            echo -e "${yellow}Vui lòng chọn chế độ xin chứng chỉ:${plain}"
            echo -e "${green}1. Chế độ HTTP tự động, tên miền của nút đã được phân giải đúng${plain}"
            echo -e "${green}2. Chế độ DNS tự động, bạn cần nhập thông tin API dịch vụ tên miền chính xác${plain}"
            echo -e "${green}3. Chế độ tự cấp chứng chỉ, tự ký hoặc cung cấp tệp chứng chỉ có sẵn${plain}"
            read -rp "Nhập lựa chọn của bạn: " certmode
            case "$certmode" in
                1 ) certmode="http" ;;
                2 ) certmode="dns" ;;
                3 ) certmode="self" ;;
            esac
            read -rp "Nhập tên miền chứng chỉ cho nút (example.com): " certdomain
            if [ $certmode != "http" ]; then
                echo -e "${red}Vui lòng chỉnh sửa tệp cấu hình thủ công sau và khởi động lại Aiko-Server!${plain}"
            fi
        fi
    fi
    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    if [ "$ipv6_support" -eq 1 ]; then
        listen_ip="::"
    fi
    node_config=""
    if [ "$core_type" == "1" ]; then 
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "0.0.0.0",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 100,
            "EnableProxyProtocol": false,
            "EnableUot": true,
            "EnableTFO": true,
            "DNSType": "UseIPv4",
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/Aiko-Server/fullchain.cer",
                "KeyFile": "/etc/Aiko-Server/cert.key",
                "Email": "Aiko-Server@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    elif [ "$core_type" == "2" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "$listen_ip",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 100,
            "TCPFastOpen": true,
            "SniffEnabled": true,
            "EnableDNS": true,
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/Aiko-Server/fullchain.cer",
                "KeyFile": "/etc/Aiko-Server/cert.key",
                "Email": "Aiko-Server@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    fi
    nodes_config+=("$node_config")
}


generate_config_file() {
    echo -e "${yellow}Hướng dẫn tạo tệp cấu hình Aiko-Server${plain}"
    echo -e "${red}Vui lòng đọc các lưu ý sau:${plain}"
    echo -e "${red}1. Hiện tại tính năng này đang trong giai đoạn thử nghiệm${plain}"
    echo -e "${red}2. Tệp cấu hình được tạo sẽ được lưu tại /etc/Aiko-Server/aiko.json${plain}"
    echo -e "${red}3. Tệp cấu hình cũ sẽ được lưu tại /etc/Aiko-Server/aiko.json.bak${plain}"
    echo -e "${red}4. Hiện tại không hỗ trợ TLS${plain}"
    echo -e "${red}5. Sử dụng tính năng này để tạo tệp cấu hình sẽ tự động bao gồm kiểm toán, bạn có chắc chắn muốn tiếp tục? (y/n)${plain}"
    read -rp "Nhập lựa chọn của bạn:" continue_prompt
    if [[ "$continue_prompt" =~ ^[Nn][Oo]? ]]; then
        exit 0
    fi
    
    nodes_config=()
    first_node=true
    core_xray=false
    core_sing=false
    fixed_api_info=false
    check_api=false
    
    while true; do
        if [ "$first_node" = true ]; then
            read -rp "Nhập địa chỉ website của máy chủ:" ApiHost
            read -rp "Nhập API Key đối với bảng điều khiển:" ApiKey
            read -rp "Có thiết lập cố định địa chỉ website và API Key không? (y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}Địa chỉ cố định đã được thiết lập${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "Bạn có muốn tiếp tục thêm cấu hình nút không? (nhấn enter để tiếp tục, nhập n hoặc no để thoát)" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "Nhập địa chỉ website của máy chủ:" ApiHost
                read -rp "Nhập API Key đối với bảng điều khiển:" ApiKey
            fi
            add_node_config
        fi
    done

    # Tạo Cores dựa trên loại hạt nhân
    if [ "$core_xray" = true ] && [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/Aiko-Server/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/Aiko-Server/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/Aiko-Server/route.json\"
        },
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": false,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            },
            \"OriginalPath\": \"/etc/Aiko-Server/sing_origin.json\"
        }]"
    elif [ "$core_xray" = true ]; then
        cores_config="[
        {
            \"Type\": \"xray\",
            \"Log\": {
                \"Level\": \"error\",
                \"ErrorPath\": \"/etc/Aiko-Server/error.log\"
            },
            \"OutboundConfigPath\": \"/etc/Aiko-Server/custom_outbound.json\",
            \"RouteConfigPath\": \"/etc/Aiko-Server/route.json\"
        }]"
    elif [ "$core_sing" = true ]; then
        cores_config="[
        {
            \"Type\": \"sing\",
            \"Log\": {
                \"Level\": \"error\",
                \"Timestamp\": true
            },
            \"NTP\": {
                \"Enable\": false,
                \"Server\": \"time.apple.com\",
                \"ServerPort\": 0
            },
            \"OriginalPath\": \"/etc/Aiko-Server/sing_origin.json\"
        }]"
    fi

    # Chuyển đến thư mục tệp cấu hình
    cd /etc/Aiko-Server
    
    # Sao lưu tệp cấu hình cũ
    mv aiko.json aiko.json.bak
    nodes_config_str="${nodes_config[*]}"
    formatted_nodes_config="${nodes_config_str%,}"

    # Tạo tệp aiko.json
    cat <<EOF > /etc/Aiko-Server/aiko.json
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": $cores_config,
    "Nodes": [$formatted_nodes_config]
}
EOF
    
    cat <<EOF > /etc/Aiko-Server/custom_outbound.json
    [
        {
            "tag": "IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4v6"
            }
        },
        {
            "tag": "IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6"
            }
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
EOF
    
    cat <<EOF > /etc/Aiko-Server/route.json
    {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "geoip:private",
                    "geoip:cn"
                ]
            },
            {
                "domain": [
                    "geosite:google"
                ],
                "outboundTag": "IPv4_out",
                "type": "field"
            },
            {
                "type": "field",
                "outboundTag": "block",
                "domain": [
                    "geosite:cn"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "domain": [
                    "regexp:(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
                    "regexp:(.+.|^)(360|so).(cn|com)",
                    "regexp:(Subject|HELO|SMTP)",
                    "regexp:(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
                    "regexp:(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
                    "regexp:(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
                    "regexp:(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
                    "regexp:(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
                    "regexp:(.+.|^)(360).(cn|com|net)",
                    "regexp:(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
                    "regexp:(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
                    "regexp:(.*.||)(netvigator|torproject).(com|cn|net|org)",
                    "regexp:(..||)(visa|mycard|gash|beanfun|bank).",
                    "regexp:(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
                    "regexp:(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
                    "regexp:(.*.||)(mycard).(com|tw)",
                    "regexp:(.*.||)(gash).(com|tw)",
                    "regexp:(.bank.)",
                    "regexp:(.*.||)(pincong).(rocks)",
                    "regexp:(.*.||)(taobao).(com)",
                    "regexp:(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
                    "regexp:(flows|miaoko).(pages).(dev)"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "127.0.0.1/32",
                    "10.0.0.0/8",
                    "fc00::/7",
                    "fe80::/10",
                    "172.16.0.0/12"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "protocol": [
                    "bittorrent"
                ]
            }
        ]
    }
EOF
        
    cat <<EOF > /etc/Aiko-Server/sing_origin.json
{
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_strategy": "prefer_ipv4"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "block",
        "geoip": [
          "private"
        ]
      },
      {
        "geosite": [
          "google"
        ],
        "outbound": "direct"
      },
      {
        "geosite": [
          "cn"
        ],
        "outbound": "block"
      },
      {
        "geoip": [
          "cn"
        ],
        "outbound": "block"
      },
      {
        "domain_regex": [
            "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
            "(.+.|^)(360|so).(cn|com)",
            "(Subject|HELO|SMTP)",
            "(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
            "(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
            "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
            "(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
            "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
            "(.+.|^)(360).(cn|com|net)",
            "(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
            "(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
            "(.*.||)(netvigator|torproject).(com|cn|net|org)",
            "(..||)(visa|mycard|gash|beanfun|bank).",
            "(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
            "(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
            "(.*.||)(mycard).(com|tw)",
            "(.*.||)(gash).(com|tw)",
            "(.bank.)",
            "(.*.||)(pincong).(rocks)",
            "(.*.||)(taobao).(com)",
            "(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
            "(flows|miaoko).(pages).(dev)"
        ],
        "outbound": "block"
      },
      {
        "outbound": "direct",
        "network": [
          "udp","tcp"
        ]
      }
    ]
  }
}
EOF

    echo -e "${green}Tệp cấu hình máy chủ aiko được tạo và dịch vụ máy chủ aiko đang được khởi động lại${plain}"
    restart 0
    before_show_menu
}

open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}Hãy từ bỏ thành công của cảng tường lửa!${plain}"
}

show_usage() {
    echo "Hướng dẫn sử dụng script quản lý Aiko-Server: "
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
    echo "Aiko-Server update x.x.x - Cài đặt phiên bản xác định của Aiko-Server"
    echo "Aiko-Server install      - Cài đặt Aiko-Server"
    echo "Aiko-Server uninstall    - Gỡ cài đặt Aiko-Server"
    echo "Aiko-Server version      - Kiểm tra phiên bản của Aiko-Server"
    echo "------------------------------------------"
}


show_menu() {
    echo -e "
  ${green}Script quản lý phía sau Aiko-Server, ${plain}${red}không áp dụng cho docker${plain}
--- https://github.com/Github-Aiko/Aiko-Server ---
  ${green}0.${plain} Chỉnh sửa cấu hình
————————————————
  ${green}1.${plain} Cài đặt Aiko-Server
  ${green}2.${plain} Cập nhật Aiko-Server
  ${green}3.${plain} Gỡ cài đặt Aiko-Server
————————————————
  ${green}4.${plain} Khởi động Aiko-Server
  ${green}5.${plain} Dừng Aiko-Server
  ${green}6.${plain} Khởi động lại Aiko-Server
  ${green}7.${plain} Kiểm tra trạng thái Aiko-Server
  ${green}8.${plain} Xem nhật ký Aiko-Server
————————————————
  ${green}9.${plain} Cài đặt khởi động tự động Aiko-Server
  ${green}10.${plain} Hủy cài đặt khởi động tự động Aiko-Server
————————————————
  ${green}11.${plain} Cài đặt bbr một cú nhấp chuột (kernel mới nhất)
  ${green}12.${plain} Xem phiên bản Aiko-Server
  ${green}13.${plain} Tạo khóa X25519
  ${green}14.${plain} Nâng cấp script bảo trì Aiko-Server
  ${green}15.${plain} Tạo file cấu hình Aiko-Server
  ${green}16.${plain} Mở tất cả cổng mạng của VPS
  ${green}17.${plain} Thoát script
 "
 # Có thể thêm cập nhật trong chuỗi string phía trên
    show_status
    echo && read -rp "Nhập lựa chọn của bạn [0-17]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_Aiko-Server_version ;;
        13) check_install && generate_x25519_key ;;
        14) update_shell ;;
        15) generate_config_file ;;
        16) open_ports ;;
        17) exit ;;
        *) echo -e "${red}Vui lòng nhập số đúng [0-17]${plain}" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "x25519") check_install 0 && generate_x25519_key 0 ;;
        "version") check_install 0 && show_Aiko-Server_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi

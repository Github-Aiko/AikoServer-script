#!/bin/bash
# Cấu hình tự động một cú nhấp chuột

# Kiểm tra hệ thống có địa chỉ IPv6 hay không
check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"  # Hỗ trợ IPv6
    else
        echo "0"  # Không hỗ trợ IPv6
    fi
}

add_node_config() {
    echo -e "${green}Vui lòng chọn loại lõi node:${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    read -rp "Vui lòng nhập lựa chọn của bạn：" core_type
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
        read -rp "Vui lòng nhập Node ID：" NodeID
        # Kiểm tra xem NodeID có phải là số nguyên dương không
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # Nếu đúng, thoát vòng lặp
        else
            echo "Lỗi: Vui lòng nhập số hợp lệ cho Node ID."
        fi
    done
    
    echo -e "${yellow}Vui lòng chọn giao thức truyền tải của node:${plain}"
    echo -e "${green}1. Shadowsocks${plain}"
    echo -e "${green}2. Vless${plain}"
    echo -e "${green}3. Vmess${plain}"
    echo -e "${green}4. Hysteria${plain}"
    echo -e "${green}5. Hysteria2${plain}"
    echo -e "${green}6. Tuic${plain}"
    echo -e "${green}7. Trojan${plain}"
    read -rp "Vui lòng nhập lựa chọn của bạn：" NodeType
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
        read -rp "Bạn có muốn node này là reality không? (y/n)" isreality
    fi
    certmode="none"
    certdomain="example.com"
    if [ "$isreality" != "y" ] && [ "$isreality" != "Y" ]; then
        read -rp "Bạn có muốn cấu hình TLS không? (y/n)" istls
        if [ "$istls" == "y" ] || [ "$istls" == "Y" ]; then
            echo -e "${yellow}Vui lòng chọn chế độ cấp chứng chỉ:${plain}"
            echo -e "${green}1. Tự động cấp chứng chỉ theo chế độ http, tên miền node đã được giải quyết chính xác${plain}"
            echo -e "${green}2. Tự động cấp chứng chỉ theo chế độ dns, cần nhập thông số API từ nhà cung cấp tên miền${plain}"
            echo -e "${green}3. Chế độ self, tự ký chứng chỉ hoặc cung cấp chứng chỉ đã có${plain}"
            read -rp "Vui lòng nhập lựa chọn của bạn：" certmode
            case "$certmode" in
                1 ) certmode="http" ;;
                2 ) certmode="dns" ;;
                3 ) certmode="self" ;;
            esac
            read -rp "Vui lòng nhập tên miền chứng chỉ của node (ví dụ: example.com)：" certdomain
            if [ $certmode != "http" ]; then
                echo -e "${red}Vui lòng tự chỉnh sửa file cấu hình sau đó khởi động lại Aiko-Server!${plain}"
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
    echo -e "${yellow}Trình hướng dẫn tạo file cấu hình Aiko-Server${plain}"
    echo -e "${red}Xin đọc kỹ các thông tin sau:${plain}"
    echo -e "${red}1. Tính năng này đang trong giai đoạn thử nghiệm${plain}"
    echo -e "${red}2. File cấu hình sẽ được lưu vào /etc/Aiko-Server/aiko.json${plain}"
    echo -e "${red}3. File cấu hình cũ sẽ được lưu vào /etc/Aiko-Server/aiko.json.bak${plain}"
    echo -e "${red}4. Hiện tại chỉ hỗ trợ TLS một phần${plain}"
    echo -e "${red}5. File cấu hình tạo ra sẽ bao gồm kiểm duyệt, bạn có chắc chắn muốn tiếp tục không? (y/n)${plain}"
    read -rp "Vui lòng nhập lựa chọn của bạn：" continue_prompt
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
            read -rp "Vui lòng nhập URL của máy chủ：" ApiHost
            read -rp "Vui lòng nhập API Key để đồng bộ với bảng điều khiển：" ApiKey
            read -rp "Bạn có muốn cố định URL máy chủ và API Key không? (y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}Đã cố định địa chỉ thành công${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "Bạn có muốn tiếp tục thêm cấu hình node không? (nhấn Enter để tiếp tục, nhập n hoặc no để thoát)" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "Vui lòng nhập URL của máy chủ：" ApiHost
                read -rp "Vui lòng nhập API Key để đồng bộ với bảng điều khiển：" ApiKey
            fi
            add_node_config
        fi
    done

    # Tạo cấu hình Cores dựa trên loại lõi
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

    # Chuyển đến thư mục chứa file cấu hình
    cd /etc/Aiko-Server
    
    # Sao lưu file cấu hình cũ
    mv aiko.json aiko.json.bak
    nodes_config_str="${nodes_config[*]}"
    formatted_nodes_config="${nodes_config_str%,}"

    # Tạo file aiko.json mới
    cat <<EOF > /etc/Aiko-Server/aiko.json
EOF

    echo -e "${green}File cấu hình Aiko-Server đã được tạo, đang khởi động lại dịch vụ${plain}"
    Aiko-Server restart
}
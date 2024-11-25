#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
while getopts "i:a:s:" opt; do
    case $opt in
        i) interface="$OPTARG";;
        a) ipaddr="$OPTARG";;
        s) size="$OPTARG";;
        :)
            echo "Invalid option: -$OPTARG requires an argument" 1>&2
            exit 1
            ;;
    esac
done

if [ -z "$ipaddr" ] || [ -z "$size" ] || [ -z "$interface" ]; then
    echo "Error: The -i and -a -s parameter is required." 1>&2
    exit 1
fi

NOW=$(date +"%Y-%m-%d-%H:%M:%S")
PCAP_FILE="/home/lingzhou/download/$ipaddr-$size-$NOW.pcap"
DELAY=$(hping3 -c 5 -S -p 80 $ipaddr 2>&1 | grep "avg" | awk -F '/' '{print $4}')
tcpdump host $ipaddr -i $interface -w $PCAP_FILE 2>/dev/null &
TCPDUMP_PID=$!
#echo $TCPDUMP_PID
#wget -q -O /dev/null http://$ipaddr/test/$size""M
START_TIME=$(date +"%Y-%m-%d-%H:%M:%S")
echo "下载开始时间: $START_TIME"
#RATE=$(wget -O /dev/null http://$ipaddr/$size 2>&1 | grep -o '[0-9.]\+ [KM]*B/s')
# 获取crul 平均下载速率默认单位bytes/sec
RATE=$(curl -o /dev/null -r 0-20000000 -s -w "%{speed_download}\n" http://$ipaddr/$size)
#echo  $RATE
END_TIME=$(date +"%Y-%m-%d-%H:%M:%S")
echo "下载结束时间: $END_TIME"
kill $TCPDUMP_PID
TOTAL_TCP_PACKETS=$(tshark -r $PCAP_FILE -nn -Y 'tcp' 2>/dev/null | wc -l)
echo "总包数 $TOTAL_TCP_PACKETS"
RETRANSMISSIONS=$(tshark -r $PCAP_FILE -nn -Y 'tcp.analysis.retransmission' 2>/dev/null | wc -l)
echo "重传包数 $RETRANSMISSIONS"
OUT_OF_ORDER=$(tshark -r $PCAP_FILE -nn -Y 'tcp.analysis.out_of_order' 2>/dev/null | wc -l)
echo "乱序包数 $OUT_OF_ORDER"
if [ $TOTAL_TCP_PACKETS -ne 0 ]; then
    LOSS_RATE=$(echo "scale=4; $RETRANSMISSIONS / $TOTAL_TCP_PACKETS * 100" | bc)
    OUT_OF_ORDER=$(echo "scale=4; $OUT_OF_ORDER / $TOTAL_TCP_PACKETS * 100" | bc)
   # byte/s换成 MB/s
    RATE_MB=$(echo "scale=2; $RATE / 1000 / 1000" | bc)
   # 格式化去除 bc 个位为0的时候不显示
    RATE_MB_FORMATTED=$(printf "%.2f" "$RATE_MB")
    echo "时延: $DELAY ms"
    echo "${location}下载速率: $RATE_MB_FORMATTED MB/s"
    echo "${location}重传率: $LOSS_RATE%"
    echo -e "${location}乱序率: $OUT_OF_ORDER% \n"
    echo -e "$START_TIME,$END_TIME,$DELAY,$RATE_MB_FORMATTED,$LOSS_RATE%,$OUT_OF_ORDER%" >> /home/lingzhou/curldownload.csv
else
    echo -e "无法计算，因为总的 TCP 包数为 0。\n"
fi

#!/bin/bash

# 校验参数数量
if [ "$#" -ne 3 ]; then
    echo "请提供正确的参数：开始日期、结束日期和文件夹路径"
    exit 1
fi

# 校验日期格式
date_regex='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
if ! [[ $1 =~ $date_regex ]] || ! [[ $2 =~ $date_regex ]]; then
    echo "日期格式不正确，请使用yyyy-mm-dd格式"
    exit 1
fi

# 校验文件夹存在性
if [ ! -d "$3" ]; then
    echo "文件夹路径不存在或不可访问"
    exit 1
fi

if [ "$3" = "/" ]; then
    echo "文件夹路径不能为根目录"
    exit 1
fi

# 从命令行参数获取开始和结束日期
start_date=$1
end_date=$2

# 获取文件夹路径
folder_path=$3

# 将日期转换为Unix时间戳
start_timestamp=$(date -d "$start_date" +%s)
end_timestamp=$(date -d "$end_date" +%s)

# 遍历目录下的文件夹
for folder in $folder_path/*; do
    if ! [[ $(basename $folder) =~ $date_regex ]]; then
        continue
    fi

    # 获取文件夹名称并转换为Unix时间戳
    folder_date=$(basename $folder)
    folder_timestamp=$(date -d "$folder_date" +%s)
    # 判断文件夹是否在指定的日期范围内，并进行删除
    if [ $folder_timestamp -ge $start_timestamp ] && [ $folder_timestamp -le $end_timestamp ]; then
        rm -rf $folder
        echo "已删除文件夹: $folder"
    fi
done

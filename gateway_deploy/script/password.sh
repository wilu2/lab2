#!/bin/bash

# 定义加密盐值
salt=7

# 定义ASCII映射表
mappingTable="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

# Encrypt函数将数字、小写字符和大写字符互相映射转换，其他字符保持不变
function Encrypt() {
    local plaintext="$1"
    local encrypted=""
    local len=${#mappingTable}

    for ((i = 0; i < ${#plaintext}; i++)); do
        char="${plaintext:$i:1}"
        index=$(expr index "$mappingTable" "$char")
        if [ "$index" -gt 0 ]; then
            newIndex=$((($index + $salt - 1) % $len + 1))
            encrypted="$encrypted${mappingTable:$newIndex-1:1}"
        else
            encrypted="$encrypted$char"
        fi
    done

    # 将encrypted进行循环左移加密
    if [ -n "$encrypted" ]; then
        pos=$(($salt % ${#encrypted}))
        encrypted="${encrypted:$pos}${encrypted:0:$pos}"
    fi

    echo "$encrypted"
}

# Decrypt函数将经过加密的内容还原为原始内容
function Decrypt() {
    local encrypted="$1"

    # 将encrypted进行循环右移解密
    if [ -n "$encrypted" ]; then
        pos=$(($salt % ${#encrypted}))
        pos=$((${#encrypted} - $pos))
        encrypted="${encrypted:$pos}${encrypted:0:$pos}"
    fi

    local plaintext=""
    local len=${#mappingTable}

    for ((i = 0; i < ${#encrypted}; i++)); do
        char="${encrypted:$i:1}"
        index=$(expr index "$mappingTable" "$char")
        if [ "$index" -gt 0 ]; then
            newIndex=$((($index - $salt - 1 + $len) % $len + 1))
            plaintext="$plaintext${mappingTable:$newIndex-1:1}"
        else
            plaintext="$plaintext$char"
        fi
    done

    echo "$plaintext"
}

# 主程序入口
if [ $# -lt 1 ]; then
    echo "Please provide a password."
    exit 1
fi

password="$1"

encrypted=$(Encrypt "$password")
echo "Encrypted: $encrypted"
decrypted=$(Decrypt "$encrypted")
echo "Decrypted: $decrypted"

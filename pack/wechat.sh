#!/usr/bin/env bash

# 计算打包大小
if [ $TAR_SIZE -gt 1073741824 ]; then
  TAR_SIZE=$(($TAR_SIZE * 10 / 1024 / 1024 / 1024))
  TAR_SIZE=$((TAR_SIZE/10)).$((TAR_SIZE%10))
  TAR_SIZE="${TAR_SIZE}GB"
elif [ $TAR_SIZE -gt 1048576 ]; then
  TAR_SIZE=$(($TAR_SIZE * 10 / 1024 / 1024))
  TAR_SIZE=$((TAR_SIZE/10)).$((TAR_SIZE%10))
  TAR_SIZE="${TAR_SIZE}MB"
elif [ $TAR_SIZE -gt 1024 ]; then
  TAR_SIZE=$(($TAR_SIZE * 10 / 1024))
  TAR_SIZE=$((TAR_SIZE/10)).$((TAR_SIZE%10))
  TAR_SIZE="${TAR_SIZE}KB"
else
  TAR_SIZE="${TAR_SIZE}bytes"
fi

# 计算流水线执行时间
CI_PIPELINE_END_TIME=$(date +'%s')
DURATION=$(( CI_PIPELINE_END_TIME - CI_PIPELINE_START_TIME ))
MINS=$(( DURATION / 60 ))
SECS=$(( DURATION % 60 ))
UpTime="${MINS}m${SECS}s"

START_TIME=$(date -d @$CI_PIPELINE_START_TIME +'%Y-%m-%d %H:%M')
Branch=$(git symbolic-ref --short HEAD)

curl 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key='"$WE_CHAT_KEY" \
      -H 'Content-Type: application/json' \
      -d '
      {
        "msgtype": "markdown",
        "markdown": {
        "content": "<font color=\"info\">'$JOB'</font> 打包成功\n
         >User: <font color=\"info\">'$GITLAB_USER_LOGIN'</font>
         >Date: <font color=\"info\">'"$START_TIME"'</font>
         >UpTime: <font color=\"info\">'$UpTime'</font>
         >Branch: <font color=\"info\">'$CI_COMMIT_REF_NAME'</font>
         >Commit: <font color=\"info\">'$CI_COMMIT_SHORT_SHA'</font>
         >MD5: <font color=\"info\">'$MD5'</font>
         >SIZE: <font color=\"info\">'$TAR_SIZE'</font>
         >Download: <font color=\"info\">'$DOWNLOAD_URL'</font>"
        }
      }'

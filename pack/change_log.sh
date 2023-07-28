# 负责向当前 git 仓库的 chang_log 分支追加日志

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

# CI_REPOSITORY_URL https://gitlab.intsig.net/textin-gateway/textin-gateway-manifest.git
# TOKEN glpat-ZDT6

suffix="${CI_REPOSITORY_URL#*@}"
REPOSITORY_URL="https://oauth2:$TOKEN@$suffix"
tag_url=$(echo "$suffix" | sed -e 's/^/https:\/\//' -e 's/\.git$/\/-\/tags\//')

if [ -z "$CI_COMMIT_TAG" ]
then
    Tag="$CI_COMMIT_SHORT_SHA"
else
    tag_url="$tag_url$CI_COMMIT_TAG"
    Tag="[$CI_COMMIT_TAG]($tag_url)"
fi

git clone $REPOSITORY_URL -b log
cd $CI_PROJECT_NAME

file="./README.md"


echo "## [$Tag]$START_TIME" >> $file
echo "" >> $file
echo "* Job: $JOB" >> $file
echo "* User: $GITLAB_USER_LOGIN" >> $file
echo "* Branch: $CI_COMMIT_REF_NAME" >> $file
echo "* UpTime: $UpTime" >> $file
echo "* Commit: $CI_COMMIT_SHORT_SHA" >> $file
echo "* SIZE: $TAR_SIZE" >> $file
echo "* MD5: $MD5" >> $file
echo "* Download: $DOWNLOAD_URL" >> $file
echo "" >> $file

git config user.email $GITLAB_USER_EMAIL
git config user.name $GITLAB_USER_LOGIN
git add .
git commit -m "log: $JOB"
git push

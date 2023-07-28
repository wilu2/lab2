#!/usr/bin/env bash

tag=$(git tag --points-at HEAD)

if [ -z "$tag" ]; then
  echo "当前 commit 无 tag"
  exit 1
fi

echo "当前 tag: $tag"

if [ $# -eq 0 ]; then
  echo "请选择要下载的模块："
  echo "1. 全量镜像"
  echo "2. 增量镜像"
  exit 1
fi

if [ $1 -eq 1 ]; then
  echo "选择了全量下载"
  # 全量下载的代码
elif [ $1 -eq 2 ]; then
  echo "选择了增量下载"
  back_tag=$(git describe --abbrev=0 --tags HEAD~1 2>/dev/null)
  if [[ -n "$back_tag" ]]; then
    echo "commit 上一个 tag 标签： $back_tag"
  else
    echo "commit 无上一个 tag 标签"
    exit 1
  fi
else
  echo "参数错误，请输入 1 或 2。"
  exit 1
fi

# 从文件中提取镜像的 tag
function get_image_array() {
    local yml="$1"
    local env="$2"

    image=()
    while read -r line; do
        image+=("$line")
    done < <(echo "$yml" | awk '/image:/ {print $2}')

    env_vars=()
    while IFS= read -r line; do
        env_vars+=("$line")
    done < <(echo "$env")

    # 循环遍历数组，并使用 sed 命令提取 ${} 中的内容并添加到新数组中
    for i in "${!image[@]}"; do
        # 提取占位符
        tag=$(echo "${image[$i]}" | sed -n 's/.*{\(.*\)}.*/\1/p')

        # 如果找到与占位符匹配的环境变量，则用该值替换占位符
        for env_var in "${env_vars[@]}"; do
            if [[ "$env_var" =~ ^$tag=(.*)$ ]]; then
                value="${BASH_REMATCH[1]}"
                image[$i]=${image[$i]/"\${$tag}"/"$value"}
            fi
        done
    done
    echo "${image[@]}"
}

# 定义文件路径变量
yml_file="./gateway_deploy/docker-compose.yml"
env_file="./gateway_deploy/.env"

# 读取当前 commit yml文件内容，获取需要下载的镜像
yml=$(cat "$yml_file")
env=$(cat "$env_file")

image_array=($(get_image_array "$yml" "$env"))


if [ $1 -eq 2 ]; then # 获取上一个版本的 tag
  yml=$(git show "$back_tag":"$yml_file")
  env=$(git show "$back_tag":"$env_file")
  diff_image_array=($(get_image_array "$yml" "$env"))
  new_array=()
  # 遍历 image_array 中的元素
  for i in "${image_array[@]}"
  do
    # 判断该元素是否和 diff_image_array 中的元素相同
    if [[ " ${diff_image_array[*]} " != *" $i "* ]]; then
      # 如果不同，则添加到 new_array 中
      new_array+=("$i")
    else
      # 如果相同，则比较 tag 是否变动
      for j in "${diff_image_array[@]}"
      do
        image_name="${i%:*}"
        image_tag="${i#*:}"
        diff_image_name="${j%:*}"
        diff_image_tag="${j#*:}"
        if [ "$image_name" == "$diff_image_name" ] && [ "$image_tag" != "$diff_image_tag" ]; then
          # 如果 tag 变动，则添加到 new_array 中
          new_array+=("$i")
        fi
      done
    fi
  done
  image_array=("${new_array[@]}")
fi

if [ ${#image_array[@]} -eq 0 ]; then
  echo "暂无新增镜像"
  exit 1
fi

echo "新增镜像: ${image_array[@]}"

for image_name in ${image_array[@]}; do
    replace_image_name=$(echo "${image_name}" | awk -F/ '{print $NF}' | sed 's/:/_/g; s/\//_/g')
    tar_name="${replace_image_name}.tar"
    skopeo copy docker://${image_name} docker-archive:$(pwd)/${tar_name}:${image_name}
    mv $(pwd)/${tar_name} $(pwd)/gateway_deploy/images/
done

KERNEL_PATH=/home/rof/src/github.com/shreejoy/Nano_rosy
OUT_PATH="out/arch/arm64/boot"
export group_id=$(jq -r '.group_id' $KERNEL_PATH/extras/info.json)
export channel_id=$(jq -r '.channel_id' $KERNEL_PATH/extras/info.json)

[[ -z "${bottoken}" ]] && echo "API_KEY not defined, exiting!" && exit 1
function sendTG() {
    curl -s "https://api.telegram.org/bot${bottoken}/sendmessage" --data "text=${*}&chat_id="$group_id"6&parse_mode=Markdown" > /dev/null
}

function clone {
    export anykernel_link=$(jq -r '.anykernel_url' $KERNEL_PATH/extras/url.json)
    export toolchain_link=$(jq -r '.toolchain_url' $KERNEL_PATH/extras/url.json)
	git clone --depth=1 --no-single-branch $anykernel_link $KERNEL_PATH/anykernel2
	git clone --depth=1 --no-single-branch $toolchain_link $KERNEL_PATH/Toolchain
   }
 
function exports {
	export KBUILD_BUILD_USER="Nano-developers"
	export KBUILD_BUILD_HOST="Nano-Team"
	export ARCH=arm64
	export SUBARCH=arm64
    PATH=$KERNEL_DIR/Toolchain/bin:$PATH
	export PATH
}
 
function build {  
for ((i=1;i<=2;i++));
do 
    DEFCONFIG=$(jq -r '.deconfig' $i.json)
	if [ -f $KERNEL_DIR/arch/arm64/configs/$DEFCONFIG ]
	then 
        export TYPE=$(jq -r '.type' $KERNEL_PATH/Nano_Extras/json/$i.json)
		export DL_URL=$(jq -r '.base_url' $KERNEL_PATH/Nano_Extras/json/url.json)
		export NUM=$(jq -r '.version' $KERNEL_PATH/Nano_Extras/json/$i.json)
		export BUILD_DATE="$(date +%M%Y%H-%d%m)"
		export FILE_NAME="Nano_Kernel-rosy-$BUILD_DATE-$TYPE-$NUM.zip"
		export LINK="$DL_URL/$TYPE/$FILE_NAME"
    else
		echo "Defconfig Mismatch"
		echo "Exiting in 5 seconds"
		sleep 5
		exit
	fi

	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	make -j${JOBS} O=out \
	CROSS_COMPILE="$KERNEL_PATH/Toolchain/bin/aarch64-linux-android-" 
	BUILD_END=$(date +"%s")
	BUILD_TIME=$(date +"%Y%m%d-%T")
	DIFF=$((BUILD_END - BUILD_START))	

	if [ -f $KERNEL_PATH/out/arch/arm64/boot/Image.gz-dtb ]
	then 
		sendTG "✅Nano for $TYPE build completed successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."
		echo "Zipping Files.."
		mv $KERNEL_PATH/$OUT_PATH/Image.gz-dtb anykernel2/Image.gz-dtb
		mv $KERNEL_PATH/anykernel2/Image.gz-dtb $KERNEL_PATH/anykernel2/zImage
		cd $KERNEL_PATH/anykernel2
		zip -r $FILE_NAME * -x .git README.md 
		rm -rf zImage
		mv $FILE_NAME $KERNEL_PATH
		cd ..
		curl --data '{"chat_id":"'"$channel_id"'", "text":"🔥 *Releasing New Build* 🔥\n\n📱Release for *$TYPE*\n\n⏱ *Timestamp* :- $(date)\n\n🔹 Download 🔹\n[$FILE_NAME]($LINK)", "parse_mode":"Markdown", "disable_web_page_preview":"yes" }' -H "Content-Type: application/json" -X POST https://api.telegram.org/bot$bottoken/sendMessage
		curl --data '{"chat_id":"'"$channel_id"'", "sticker":"CAADBQADHQADW31iJK_MskdmvJABAg" }' -H "Content-Type: application/json" -X POST https://api.telegram.org/bot$bottoken/sendSticker
        fi
	else 
		sendTG "❌ Nano for $TYPE build failed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."
	fi	
}



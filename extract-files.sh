#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=beryl
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=true

export PATCHELF_VERSION=0_17_2

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup {
    case "$1" in
        system_ext/priv-app/ImsService/ImsService.apk)
            apktool_patch "${2}" "${MY_DIR}/blob-patches/ImsService.patch" -r
            [ "$2" = "" ] && return 0
            ;;
        system_ext/etc/init/init.vtservice.rc|vendor/etc/init/android.hardware.neuralnetworks-shim-service-mtk.rc)
            sed -i "s|start|enable|g" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        system_ext/lib64/libimsma.so)
            "${PATCHELF}" --replace-needed "libsink.so" "libsink-mtk.so" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        system_ext/lib64/libsink-mtk.so)
            "$PATCHELF" --add-needed "libaudioclient_shim.so" "$2"
            [ "$2" = "" ] && return 0
            ;;
        vendor/bin/hw/mt6855/camerahalserver| \
        vendor/lib64/hw/mt6855/android.hardware.camera.provider@2.6-impl-mediatek.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            "${PATCHELF}" --replace-needed "libbinder.so" "libbinder-v32.so" "${2}"
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        vendor/bin/hw/android.hardware.security.keymint@1.0-service.mitee)
            "$PATCHELF" --add-needed "android.hardware.security.rkp-V3-ndk.so" "$2"
            "$PATCHELF" --replace-needed "android.hardware.security.keymint-V1-ndk_platform.so" "android.hardware.security.keymint-V3-ndk.so" "$2"
            [ "$2" = "" ] && return 0
            ;;
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek-64b)
            "$PATCHELF" --add-needed "libstagefright_foundation-v33.so" "$2"
            "${PATCHELF}" --replace-needed "libavservices_minijail_vendor.so" "libavservices_minijail.so" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        vendor/etc/init/android.hardware.neuralnetworks-shim-service-mtk.rc)
            sed -i 's/start/enable/' "$2"
            [ "$2" = "" ] && return 0
            ;;
        vendor/lib64/hw/mt6855/android.hardware.camera.provider@2.6-impl-mediatek.so)
            "${PATCHELF}" --add-needed libshim_camera_metadata.so "${2}"
            [ "$2" = "" ] && return 0
            ;;
        vendor/lib64/hw/android.hardware.thermal@2.0-impl.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            [ "$2" = "" ] && return 0
            ;;
        vendor/lib64/mt6855/libaalservice.so|\
        vendor/bin/mnld)
            "$PATCHELF" --add-needed "android.hardware.sensors@1.0-convert-shared.so" "$2"
            [ "$2" = "" ] && return 0
            ;;
        vendor/lib/hw/audio.primary.mediatek.so)
             "${PATCHELF}" --replace-needed "libalsautils.so" "libalsautils-v31.so" "${2}"
             ;;
        vendor/lib*/libmtkcam_stdutils.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "$2"
            [ "$2" = "" ] && return 0
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "${1}" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"

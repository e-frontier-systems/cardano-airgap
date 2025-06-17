#!/bin/bash
#set -e
set -u
#set -x

CTOOL_VERSION=0.6.51


SHARE_DIR="/mnt/share"

# General exit handler
cleanup() {
    [[ -n $1 ]] && err=$1 || err=$?
    [[ $err -eq 0 ]] && clear
    tput cnorm # restore cursor
    [[ -n ${exit_msg} ]] && echo -e "${exit_msg}" || echo -e "SPO JAPAN GUILD TOOL for Airgap Closed!"
    tput sgr0  # turn off all attributes
    exit "$err"
}

trap cleanup HUP INT TERM
trap 'stty echo' EXIT

myExit() {
    exit_msg="$2"
    cleanup "$1"
}


ctool_upgrade() {

    cp ${SHARE_DIR}/ctool.sh "${HOME}/bin/"
    chmod 755 "${HOME}/bin/ctool.sh"
    rm ${SHARE_DIR}/ctool.sh

    echo "'ctool.sh'をバージョンアップしました!!"
    pressKeyEnter "Enterキーを押してリロードしてください"

    "${HOME}/bin/ctool.sh"
    exit
    
}

ctool_update() {
    clear
    echo "'share'ディレクトリに新しいバージョンの'ctool.sh'をコピーしてください。"
    pressKeyEnter "コピーができたらEnterキーを押下してください"
    if [ -f "${SHARE_DIR}/ctool.sh" ]; then

        check_self_update

    else

        echo_red "'ctool.sh'ファイルが'share'ディレクトリに見つかりませんでした。"
        echo
        pressKeyEnter
        main

    fi

}

#
# shareディレクトリにctool.shがないかチェックする
#
check_self_update() {

    if [ -f ${SHARE_DIR}/ctool.sh ]; then
        VERSION=$(cat ${SHARE_DIR}/ctool.sh | grep CTOOL_VERSION= | head -n 1)
        VERSION_NUMBER=$(get_version_number "${VERSION:14}")

        MY_VERSION_NUMBER=$(get_version_number "$CTOOL_VERSION")

        if (( VERSION_NUMBER > MY_VERSION_NUMBER )); then

            HASH=$(sha256sum ${SHARE_DIR}/ctool.sh)

            clear
            echo
            echo_green "新しい'ctool.ch'を'share'ディレクトリ内に検出しました!!"
            echo
            echo
            echo -n "現バージョン："
            echo_yellow "v${CTOOL_VERSION}"
            echo
            echo -n "新バージョン："
            echo_yellow "v${VERSION:14}"
            echo
            echo -n "ハッシュ値："
            echo_yellow "${HASH:0:64}"
            echo
            echo
            echo
            echo_green "v${CTOOL_VERSION} -> v${VERSION:14}"
            echo
            echo
            if readYn "バージョンアップしますか？"; then
                ctool_upgrade
            fi
        else

            clear
            echo
            echo_red "'share'ディレクトリに古いバージョンの'ctool.sh'が見つかりました。"
            echo
            echo
            echo -n "現バージョン："
            echo_yellow "v${CTOOL_VERSION} (${VERSION_NUMBER})"
            echo
            echo -n "旧バージョン："
            echo_yellow "v${VERSION:14} (${MY_VERSION_NUMBER})"
            echo
            echo
            echo
            if readYn "削除しますか？"; then
                rm ${SHARE_DIR}/ctool.sh
            fi

        fi
    fi
}


COLDKEYS_DIR="${HOME}/cold-keys"
COLDKEYS_TARBALL="keys.tar.gz"
COLDKEYS_ENCFILE="${SHARE_DIR}/${COLDKEYS_TARBALL}.enc"


check_cli_update() {

    clear

}


#
# コールドキーがインストールされているかチェックします
#
check_coldkeys_exists() {
    echo "暗号化済みコールドキーをチェックしています..."
    echo
    encrypted_keys_exists
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "コールドキーをチェックしています..."
        echo
        keys_is_installed
        if [ $? -ne 0 ]; then
            echo_red "コールドキーがインポートされていません。"
            echo
            echo

            choice=$(gum choose --limit 1 --height 6 --header "===== 初期化メニュー =====" "1. コールドキーをインポートする" "2. 新規ノードを立ち上げる" "h. メインメニュー")
            echo " $choice"
            choice=${choice:0:1}
            case $choice in
            1 )
                install_coldkeys
                return $?
                ;;
            2 )
                generate_new_node
                return $?
                ;;
            h )
                return 0
                ;;
            esac
        else
            return 0
        fi
    else
        return 0
    fi
    return 0
}

#
# バージョン番号を数値に変換する
#
get_version_number() {
    VERSION=$1
    if (( ${#VERSION} < 5 )); then
        echo "0" | bc
    fi
    echo "$VERSION" | awk -F. '{printf "%2d%02d%02d", $1,$2,$3}' | xargs echo | bc
}

is_integer() {
    [[ -z "${1}" ]] && return 1
    printf "%d" "${1}" >/dev/null 2>&1
}


echo_red() {
    tput setaf 1 && echo -n "$1" && tput setaf 7
}

echo_green() {
    tput setaf 2 && echo -n "$1" && tput setaf 7
}

echo_yellow() {
    tput setaf 3 && echo -n "$1" && tput setaf 7
}

echo_blue() {
    tput setaf 4 && echo -n "$1" && tput setaf 7
}

echo_magenta() {
    tput setaf 5 && echo -n "$1" && tput setaf 7
}


main() {
    check_self_update
    check_network
    check_coldkeys_exists
    main_menu
}

quit() {
    clear
    echo
    myExit 0 ""
}

readYn() {
    if existsGum; then
        if gum confirm "${1}" --affirmative="は  い" --negative="いいえ"; then
            return 0
        fi
        return 1
    else
        # shellcheck disable=SC2162
        read -n 1 -p "${1} [Y/n]" ANS

        case $ANS in
            "" | [Yy]* )
                return 0
                ;;
            * )
                return 1
                ;;
        esac
    fi
}

pressKeyEnter() {
    if (($# == 1)); then
        # shellcheck disable=SC2162
        read -r -p "$1"
    else
        # shellcheck disable=SC2162
        read -r -p "続行するにはエンターキーを押してください: "
    fi
}

existsGum() {
    if type "gum" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}


#
# lib: キーのファイルパスの配列を返します
#
get_keys() {
    keys=(
        '/cold-keys/node.counter'
        '/cold-keys/node.skey'
        '/cold-keys/node.vkey'
        '/cnode/payment.addr'
        '/cnode/payment.skey'
        '/cnode/payment.vkey'
        '/cnode/vrf.skey'
        '/cnode/vrf.vkey'
        '/cnode/stake.addr'
        '/cnode/stake.skey'
        '/cnode/stake.vkey'
    )
    echo "${keys[@]}"
}


#
# ターゲットネットワークチェックおよび初期化
#
# shellcheck disable=SC1091
check_network() {

    if [ -f "$HOME/.cnoderc" ]; then
        source "$HOME/.cnoderc"
    fi

    if [ ! -v NODE_CONFIG ] || [ -z "$NODE_CONFIG" ]; then
        echo_red "NODE_CONFIG 環境変数が定義されていません"
        echo
    else
        if [ ! -v NODE_NETWORK ] || [ -z "$NODE_NETWORK" ]; then
            echo_red "NODE_NETWORK 環境変数が定義されていません"
            echo
        else
            if [ ! -v CARDANO_NODE_NETWORK_ID ] || [ -z "$CARDANO_NODE_NETWORK_ID" ]; then
                echo_red "CARDANO_NODE_NETWORK_ID 環境変数が定義されていません"
                echo
            else
                return 0
            fi
        fi
    fi

    echo
    echo
    network=$(gum choose --limit 1 --height 6 --header "接続するネットワークを選択してください (通常はメインネットを選択してください)" "1. メインネット" "2. テストネット(Preview)" "3. テストネット(PreProd)")
    echo " $network"
    network=${network:0:1}
    case $network in
        1 )
            name="メインネット"
            ;;
        2 )
            name="テストネット(Preview)"
            ;;
        3 )
            name="テストネット(PreProd)"
            ;;
    esac

    if ! readYn "「${name}」でよろしいですか？"; then
        return 1
    fi

    {
        echo "if [ ~/.cnoderc ]; then"
        echo "  source ~/.cnoderc"
        echo "fi"
    } >> "$HOME/.bashrc"

    case $network in
        1 )
            echo export NODE_CONFIG=mainnet >> "$HOME/.cnoderc"
            echo export NODE_NETWORK='"--mainnet"' >> "$HOME/.cnoderc"
            echo export CARDANO_NODE_NETWORK_ID=mainnet >> "$HOME/.cnoderc"
            ;;
        2 )
            echo export NODE_CONFIG=preview >> "$HOME/.cnoderc"
            echo export NODE_NETWORK='"--testnet-magic 2"' >> "$HOME/.cnoderc"
            echo export CARDANO_NODE_NETWORK_ID=2 >> "$HOME/.cnoderc"
            ;;
        3 )
            echo export NODE_CONFIG=preprod >> "$HOME/.cnoderc"
            echo export NODE_NETWORK='"--testnet-magic 1"' >> "$HOME/.cnoderc"
            echo export CARDANO_NODE_NETWORK_ID=1 >> "$HOME/.cnoderc"
            ;;
    esac

    source "$HOME/.cnoderc"

    return 0
}


#
# lib: キーファイルが全てインストールされているかどうかを返します
#
keys_is_installed() {

    unlock_keys

    IFS=' '
    keys_array=$(get_keys)
    # shellcheck disable=SC2206
    keys=($keys_array)

    for i in "${!keys[@]}"; do
        if [ ! -s "${HOME}${keys[$i]}" ]; then
            echo_red "${keys[$i]}がみつかりません..."
            return 1
        fi
    done

    lock_keys

    return 0
}

#
# lib: 暗号化済みコールドキーがインストールされているかどうかを返します
#
encrypted_keys_exists() {

    if [ -s "${COLDKEYS_ENCFILE}" ]; then
        return 0
    fi

    return 1
}


#
# 新しいノードの構築
#
generate_new_node() {

    create_pool_cert_script

    # コールドキーの作成
    echo_green "コールドキーとカウンターファイルを生成しています..."
    echo
    echo
    cd "$HOME/cold-keys"

    if ! cardano-cli conway node key-gen \
        --cold-verification-key-file node.vkey \
        --cold-signing-key-file node.skey \
        --operational-certificate-issue-counter node.counter; then

        echo_red "コールドキーとカウンターファイルの生成に失敗しました"
        echo
        return 1
    fi

    chmod 400 node.vkey
    chmod 400 node.skey

    echo_green "コールドキーとカウンターファイルを生成しました"
    echo
    echo

    sleep 1

    cd "$NODE_HOME"

    while :
    do

        echo
        echo_yellow "kes.skey と kes.vkey を BP から share ディレクトリにコピーしてください"
        echo
        echo

        kes_key="0"
        while [ "$kes_key" -ne "1" ]
        do
            read -r -p "コピーが出来たらEnterキーを押してください"

            if [ ! -f $SHARE_DIR/kes.skey ]; then
                echo_red "kes.skey が share ディレクトリに見つかりません"
                echo
                kes_key=0
            else
                kes_key=1
            fi
            if [ ! -f $SHARE_DIR/kes.vkey ]; then
                echo_red "kes.vkey が share ディレクトリに見つかりません"
                echo
                kes_key=0
            else
                kes_key=1
            fi
        done

        # kesファイルをコピー
        cp $SHARE_DIR/kes.skey "$NODE_HOME/kes.skey"
        cp $SHARE_DIR/kes.vkey "$NODE_HOME/kes.vkey"

        SHA256=$(sha256sum kes.vkey | cut -d ' ' -f 1);

        echo_magenta "kes.vkey のハッシュ値がBPと一致していることを確認してください"
        echo
        echo
        echo -n "kes.vkey >> "
        echo_yellow "$SHA256"
        echo
        echo
        if readYn "ハッシュ値は一致していますか？"; then
            break;
        fi
        echo_red "再度 kes.vkey/kes.skey ファイルを BP から share ディレクトリに転送し直してください"
        echo
        echo
    done


    # 運用証明書を発行
    echo_green "運用証明書を発行します..."
    echo
    echo
    while :
    do
        echo_magenta "BPで表示された startKesPeriod の値を入力してください"
        echo
        echo
        read -r -p "半角数字で入力しEnterを押してください >" StartKesPeriod

        echo
        echo -n "startKesPeriodの値: "
        echo_green "${StartKesPeriod}"
        echo
        echo
        if readYn "上記で合っていますか？"; then
            break
        fi
    done

    echo "運用証明書を発行しています..."
    echo

    if ! cardano-cli conway node issue-op-cert \
        --kes-verification-key-file kes.vkey \
        --cold-signing-key-file "$HOME/cold-keys/node.skey" \
        --operational-certificate-issue-counter "$HOME/cold-keys/node.counter" \
        --kes-period "${StartKesPeriod}" \
        --out-file node.cert; then

        echo_red "運用証明書の発行に失敗しました"
        echo
        echo
        return 1
    fi

    cp node.cert "${SHARE_DIR}/node.cert"

    echo_green "node.cert ファイルを share ディレクトリに出力しました"
    echo
    echo_magenta "このファイルを BP の cnode ディレクトリにコピーしてください"
    echo
    echo_magenta "その後 node.cert ファイルのハッシュ値が一致しているか確認してください"
    echo
    echo
    SHA256=$(sha256sum node.cert | cut -d ' ' -f 1)
    echo -n "node.cert >> "
    echo_yellow "$SHA256"
    echo
    echo
    read -r -p "BPとハッシュ値が一致したらEnterキーを押してください"
    echo
    echo


    # 支払アドレスキーの作成
    echo
    echo_green "支払アドレスキーを作成しています..."
    echo

    if ! cardano-cli conway address key-gen \
        --verification-key-file payment.vkey \
        --signing-key-file payment.skey; then

        echo_red "支払アドレスキーの作成に失敗しました"
        echo
        return 1
    fi

    # ステークアドレスキーの作成
    echo
    echo_green "ステークアドレスキーを作成しています..."
    echo

    if ! cardano-cli conway stake-address key-gen \
        --verification-key-file stake.vkey \
        --signing-key-file stake.skey; then

        echo_red "ステークアドレスキーの作成に失敗しました"
        echo
        return 1
    fi

    # ステークアドレスの作成
    echo
    echo_green "ステークアドレスを作成しています..."
    echo

    if ! cardano-cli conway stake-address build \
        --stake-verification-key-file stake.vkey \
        --out-file stake.addr \
        "$NODE_NETWORK"; then

        echo_red "ステークアドレスの作成に失敗しました"
        echo
        return 1
    fi

    # 支払用アドレスの作成
    echo
    echo_green "支払用アドレスを作成しています..."
    echo

    if ! cardano-cli conway address build \
        --payment-verification-key-file payment.vkey \
        --stake-verification-key-file stake.vkey \
        --out-file payment.addr \
        "$NODE_NETWORK"; then

        echo_red "支払用アドレスの作成に失敗しました"
        echo
        return 1
    fi

    chmod 400 payment.vkey
    chmod 400 payment.skey
    chmod 400 stake.vkey
    chmod 400 stake.skey
    chmod 400 stake.addr
    chmod 400 payment.addr

    cp payment.addr $SHARE_DIR/payment.addr
    cp stake.addr $SHARE_DIR/stake.addr

    echo
    echo_green "payment.addrとstake.addrファイルをshareディレクトリに出力しました"
    echo
    echo_magenta "これらのファイルをBPのcnodeディレクトリにコピーしてください"
    echo
    echo
    echo_magenta "BP側の指示に従い、支払い用アドレスへの入金などを行なってください"
    echo
    echo
    read -r -p "BP側の操作が完了したらEnterキーを押して次の手順へ進みます"


    ## ステークアドレスの登録
    # ステーク証明書を作成
    echo_green "ステーク証明書を作成しています..."
    echo
    echo
    
    if ! cardano-cli conway stake-address registration-certificate \
            --stake-verification-key-file stake.vkey \
            --out-file stake.cert; then

        echo_red "ステーク証明書の作成に失敗しました"
        echo
        read -r
        return 1
    fi

    echo_green "stake.certファイルをshareディレクトリに出力しました"
    echo
    echo_magenta "stake.certファイルをBPのcnodeディレクトリにコピーしてください"
    echo
    echo
    echo_magenta "BP側の指示に従い、ステークアドレスを登録するトランザクションファイルを作成してください"
    echo

    while :
    do
        echo_magenta "BPからtx.rawファイルをshareディレクトリにコピーしてください"
        echo
        echo
        echo_magenta "コピーが出来たらEnterキーを押してください"
        read -r -p " > "

        echo
        echo
        if [ -f "${SHARE_DIR}/tx.raw" ]; then
            break
        fi
        echo_red "shareディレクトリにtx.rawファイルが見つかりませんでした"
        echo
        echo
    done

    cp "${SHARE_DIR}/tx.raw" "${NODE_HOME}/tx.raw"

    # ステークアドレスの登録(トランザクションファイルへの署名)
    if ! cardano-cli conway transaction sign \
        --tx-body-file tx.raw \
        --signing-key-file payment.skey \
        --signing-key-file stake.skey \
        "${NODE_NETWORK}" \
        --out-file tx.signed; then

        echo_red "トランザクションファイルへの署名に失敗しました"
        echo
        return 1
    fi

    echo_green "tx.signedファイルをshareディレクトリに出力しました"
    echo
    echo
    echo_magenta "tx.signedファイルをBPのcnodeにコピーしてください"
    echo
    echo
    echo_magenta "BPでトランザクションの送信が完了したらEnterキーを押してください"
    read -r -p " > "
    echo
    echo
    echo_green "プール登録証明書の作成を行います"
    echo
    while :
    do
        echo
        echo_magenta "BPからvrf.vkeyとpoolMetaDataHash.txtをshareディレクトリにコピーしてください"
        echo
        echo
        echo_magenta "コピーが出来たらEnterキーを押してください"
        read -r -p " > "
        echo
        echo
        FOUND=0
        if [ -f "${SHARE_DIR}/vrf.vkey" ]; then
            FOUND=$((FOUND++))
        else
            echo_red "shareディレクトリにvrf.vkeyが見つかりませんでした"
            echo
            echo
        fi
        if [ -f "${SHARE_DIR}/poolMetaDataHash.txt" ]; then
            FOUND=$((FOUND++))
        else
            echo_red "shareディレクトリにpoolMetaDataHash.txtが見つかりませんでした"
            echo
            echo
        fi

        if [ $FOUND -eq "2" ]; then
            
            # NODE_HOMEへコピー
            cp "${SHARE_DIR}/vrf.vkey" "${NODE_HOME}/vrf.vkey"
            cp "${SHARE_DIR}/poolMetaDataHash.txt" "${NODE_HOME}/poolMetaDataHash.txt"

            SHA256=$(sha256sum vrf.vkey | cut -d ' ' -f 1)
            echo_magenta "vrf.keyのハッシュ値が一致していることを確認してください"
            echo
            echo
            echo -n "vrf.vkey >> "
            echo_green "${SHA256}"
            echo
            echo
            if readYn "ハッシュ値は一致していますか?"; then
                break
            fi
        fi
    done

    create_pool_cert_script

    read -r 
}


create_pool_cert_script()
{
    # pool.certを作成
    while :
    do
        echo_magenta "BPで表示されたminPoolCost(最低固定費)を入力してEnterを押してください"
        read -r -p "[170000000] > " MinPoolCost
        echo
        if is_integer "$MinPoolCost"; then
            MinPoolCostAda=$(echo "$MinPoolCost / 1000000" | bc)
            if readYn "最低固定費は ${MinPoolCostAda}ADA (${MinPoolCost}lovelace)であっていますか?"; then
                break
            fi
        else
            echo_red "最低固定費に数値以外の値が入力されました"
            echo
        fi
    done


    while :
    do
        echo_magenta "誓約数(ADA)を入力してEnterキーを押してください"
        read -r -p "[100] > " POOLPLEDGE
        echo
        if is_integer "$POOLPLEDGE"; then
            if [ "$POOLPLEDGE" -lt 0 ]; then
                echo_red "誓約数には0ADA以上の値を指定してください"
                echo
            else
                break
            fi
        else
            echo_red "誓約数に数値以外の値が入力されました"
            echo
        fi
    done

    while :
    do
        echo_magenta "固定手数料(ADA)を入力してEnterキーを押してください"
        read -r -p "[170] > " POOLCOST
        echo
        if is_integer "$POOLCOST"; then
            if [ "${POOLCOST}" -lt "${MinPoolCostAda}" ]; then
                echo_red "固定手数料には最低固定費(${MinPoolCostAda}ADA)以上の値を指定してください"
                echo
            else
                break
            fi
        else
            echo_red "固定手数料に数値以外の値が入力されました"
            echo
        fi
    done

    while :
    do
        echo_magenta "変動手数料(%)を入力してEnterキーを押してください"
        read -r -p "[5] > " POOLMARGIN
        echo
        if is_integer "$POOLMARGIN"; then
            if [ "${POOLMARGIN}" -lt 0 ]; then
                echo_red "変動手数料には0以上の値を指定してください"
                echo
            elif [ "${POOLMARGIN}" -ge 100 ]; then
                echo_red "変動手数料に100%以上の値を指定することは出来ません"
                echo
            else
                POOLMARGIN=$(echo "${POOLMARGIN} / 100" | bc)
                break
            fi
        else
            echo_red "変動手数料に数値以外の値が入力されました"
            echo
        fi
    done


    echo_green "リレーの情報を入力します"
    echo
    echo
    menu=$(gum choose --limit 1 --height 3 --header "===== リレー情報の指定方法を選択してください =====" "1. IPv4アドレス方式" "2. DNS方式" "3. ラウンドロビンDNSベース SRV DNS record")
    echo " $menu"
    menu=${menu:0:1}
    case $menu in
        1 )
            # IPv4アドレス方式
            ARG="pool-relay-ipv4"
            COUNT=0
            while :
            do
                ((COUNT++))
                echo_magenta "${COUNT}つ目のリレーノードのグローバルIPアドレスを入力してください"
                echo
                read -r -p " > " IP
                echo_magenta "${COUNT}つ目のリレーノードのポート番号を入力してください"
                echo
                read -r -p " > " PORT
                echo 
                HOSTS[COUNT]="$IP $PORT"

                if ! readYn "さらにリレーノードを追加しますか？"; then
                    break
                fi
            done
            ;;
        2 )
            # DNS方式
            ARG="single-host-pool-relay"
            COUNT=0
            while :
            do
                ((COUNT++))
                echo_magenta "${COUNT}つ目のリレーノードのドメイン名を入力してください"
                echo
                read -r -p " > " DNS
                echo_magenta "${COUNT}つ目のリレーノードのポート番号を入力してください"
                echo
                read -r -p " > " PORT
                echo
                HOSTS[COUNT]="$DNS $PORT"

                if ! readYn "さらにリレーノードを追加しますか？"; then
                    break
                fi
            done
            ;;
        3 )
            # ラウンドロビンDNS
            ARG="multi-host-pool-relay"
            echo_magenta "リレーのドメイン名を入力してください"
            echo
            read -r -p " > " DNS
            echo_magenta "リレーのポート番号を入力してください"
            echo
            read -r -p " > " PORT
            echo
            HOSTS[0]="$DNS $PORT"
            ;;
    esac
    
    echo
    echo_magenta "メタデータURLを入力してEnterキーを押してください"
    echo
    read -r -p " > " METADATA_URL
    echo


    echo
    echo_green "プール運用証明書を発行するためのスクリプトを書き出しています..."
    echo

    {
        echo "cd $NODE_HOME"
        echo "cardano-cli conway stake-pool registration-certificate \\"
        echo "    --cold-verification-key-file $HOME/cold-keys/node.vkey \\"
        echo "    --vrf-verification-key-file vrf.vkey \\"
        echo "    --pool-pledge ${POOLPLEDGE}000000 \\"
        echo "    --pool-cost ${POOLCOST}000000 \\"
        echo "    --pool-margin ${POOLMARGIN} \\"
        echo "    --pool-reward-account-verification-key-file stake.vkey \\"
        echo "    --pool-owner-stake-verification-key-file stake.vkey \\"
        echo "    ${NODE_NETWORK} \\"
    } > poolcert.sh

    for item in "${HOSTS[@]}"
    do
        TARGET=$(echo "$item" | cut -d ' ' -f 1)
        PORT=$(echo "$item" | cut -d ' ' -f 2)

        echo "    --${ARG} ${TARGET} \\" >> poolcert.sh
        echo "    --pool-relay-port ${PORT} \\" >> poolcert.sh
    done

    METADATA_HASH=$(cat poolMetaDataHash.txt)
    {
        echo "    --metadata-url ${METADATA_URL} \\"
        echo "    --metadata-hash ${METADATA_HASH} \\"
        echo "    --out-file pool.cert"
    } >> poolcert.sh


    echo
    echo_green "プール運用証明書を発行するためのスクリプトの書き出しが完了しました"
    echo
    echo
    echo

    # shellcheck disable=SC1091
    source poolcert.sh

    if [ ! -f pool.cert ]; then
        echo_red "プール運用証明書の発行に失敗しました"
        echo
        echo
        return 1
    fi


    echo
    echo_green "ステークプールに誓約するためのファイルを出力します"
    echo
    echo

    if ! cardano-cli conway stake-address stake-delegation-certificate \
        --stake-verification-key-file stake.vkey \
        --cold-verification-key-file "$HOME/cold-keys/node.vkey" \
        --out-file deleg.cert; then
    
        echo_red "ステークプール誓約用のファイルの作成に失敗しました"
        echo
        echo
        return 1
    fi

    cp pool.cert "$SHARE_DIR/pool.cert"
    cp deleg.cert "$SHARE_DIR/deleg.cert"


    echo_magenta "shareディレクトリにpool.certとdeleg.certファイルを出力しました"
    echo
    echo
    echo_magenta "この2つのファイルをBPのcnodeディレクトリにコピーしてください"
    echo
    echo
    echo_magenta "BPでトランザクションファイルが生成されたらEnterキーを押してください"
    read -r -p "> "
    echo
    echo
    echo_magenta "BPからtx.rawファイルをshareディレクトリにコピーしてください"
    echo
    echo
    echo_magenta "コピーが出来たらEnterキーを押してください"
    read -r -p "> "
    echo
    echo
    echo_green "トランザクションファイルに署名しています..."
    echo
    echo

    if ! cardano-cli conway transaction sign \
        --tx-body-file tx.raw \
        --signing-key-file payment.skey \
        --signing-key-file "$HOME/cold-keys/node.skey" \
        --signing-key-file stake.skey \
        "$NODE_NETWORK" \
        --out-file tx.signed; then

        echo_red "トランザクションファイルへの署名に失敗しました"
        echo
        echo
        return 1
    fi

    cp tx.signed "$SHARE_DIR/tx.signed"

    echo_green "秘密鍵をロックしています..."
    echo
    echo
    chmod a-rwx "$HOME/cold-keys"


    echo_magenta "署名済みトランザクションファイルtx.signedファイルをshareディレクトリに出力しました"
    echo
    echo
    echo_magenta "BPのcnodeディレクトリにコピーしてトランザクションの送信処理を行なってください"
    echo
    echo
    echo_magenta "BPにてトランザクションの送信が完了したらEnterキーを押してください"
    read -r -p "> "


    echo_green "ステークプールIDの出力を行なっています..."

    chmod u+rwx "$HOME/cold-keys"

    cardano-cli conway stake-pool id --cold-verification-key-file "$HOME/cold-keys/node.vkey" --output-format bech32 --out-file pool.id-bech32
    cardano-cli conway stake-pool id --cold-verification-key-file "$HOME/cold-keys/node.vkey" --output-format hex --out-file pool.id
    
    chmod a-rwx "$HOME/cold-keys"


    echo_magenta "shareディレクトリにpool.id-bech32とpool.idファイルを出力しました"
    echo
    echo
    echo_magenta "この2つのファイルをBPのcnodeディレクトリにコピーしてください"
    echo
    echo
    echo_magenta "コピーが完了しプールがブロックチェーンに登録されたことを確認したらEnterキーを押してください"
    read -r -p "> "
    
    echo


    if readYn "キーを暗号化しますか？"; then
        encrypt_keys
    fi

    return 0;
}


#
# コールドキーをインストールします
#
install_coldkeys() {

    clear
    echo

    if encrypted_keys_exists; then
        echo_red "既に暗号化済みコールドキーがインストールされています"
        echo
        echo
        pressKeyEnter
        return 1
    fi

    IFS=' '
    keys_array=$(get_keys)
    # shellcheck disable=SC2206
    keys=($keys_array)

    echo
    echo "'share'ディレクトリに以下のファイルをコピーしてください。"
    echo 
    for i in "${!keys[@]}"; do
        echo "${keys[$i]}"
    done

    while true; do
        echo
        pressKeyEnter "'share'ディレクトリにコピーが出来たらEnterキーを押下してください"
        clear

        ng=0
        err=""
        for i in "${!keys[@]}"; do
            path="$SHARE_DIR${keys[$i]}"
            if [ -f "$path" ]; then
                if [ -s "$path" ]; then
                    echo_green '[✓]'
                else
                    echo_red '[×]'
                    ((ng=ng+1))
                    err='ファイルが空です'
                fi
            else
                echo_red '[×]'
                ((ng=ng+1))
                err='ファイルが見つかりません'
            fi
            echo " ${keys[$i]} ... ${err}"
        done
        
        if [ $ng -eq 0 ]; then
            break
        else
            echo
            echo_red "ファイルの一部が空か見つかりません"
            echo
            echo
            if ! readYn "再度チェックをおこないますか？"; then
                return 1
            fi
        fi
    done

    echo
    echo_green 'インポートの準備が整いました！'
    echo
    echo
    if readYn "インポートを開始しますか？"; then

        echo

        unlock_keys

        for i in "${!keys[@]}"; do
            src="${SHARE_DIR}${keys[$i]}"
            dst="/home/cardano${keys[$i]}"

            echo "${src} => ${dst}"
            
            if ! cp "${src}" "${dst}"; then
                delete_coldkeys
                echo
                echo_red "ファイルのコピーに失敗しました"
                echo
                echo
                pressKeyEnter "再度お試しください"
                return 1
            fi

        done

        lock_keys

        echo
        echo "'share'フォルダのデータを削除しています..."
        rm -rf "${SHARE_DIR}/cold-keys"
        rm -rf "${SHARE_DIR}/cnode"

        echo
        echo_green "コールドキーのインポートが正常に完了しました！"
        echo
        echo
        if readYn "コールドキーの暗号化をおこないますか？"; then

            if ! encrypt_keys; then
                return $?
            fi

        fi
    fi

    main_menu
}


#
# KESの更新
#
reflesh_kes() {

    while true; do

        clear
        echo
        echo "■ ブロックプロデューサーノードで gtool を起動し、KESの更新を始めて下さい。"
        echo
        echo "1.BPのkes.vkeyとkes.skey をエアギャップのcnodeディレクトリにコピーしてください"
        echo 
        echo "上記の表示が出たら、以下の2つのファイルをshareディレクトリにコピーしてください"
        echo "  kes.vkey"
        echo "  kes.skey"
        echo

        pressKeyEnter "コピーが出来たらEnterキーを押してください"

        if [ -s ${SHARE_DIR}/kes.vkey ] && [ -f ${SHARE_DIR}/kes.vkey ]; then

            if [ -s ${SHARE_DIR}/kes.skey ] && [ -f ${SHARE_DIR}/kes.skey ]; then

                break

            else

                echo_red "kes.skeyファイルが空かファイルが見つかりません。"
                echo

            fi

        else

            echo_red "kes.vkeyファイルが空かファイルが見つかりません。"
            echo

        fi

        echo
        if readYn "もう一度チェックしますか？"; then
            continue;
        else
            return 1;
        fi

    done

    cp ${SHARE_DIR}/kes.vkey "${NODE_HOME}/"
    cp ${SHARE_DIR}/kes.skey "${NODE_HOME}/"

    cd "${NODE_HOME}" || (echo_red "${NODE_HOME}ディレクトリへの移動に失敗しました" && main_menu)

    VKEY=$(sha256sum kes.vkey | cut -d ' ' -f 1)
    SKEY=$(sha256sum kes.skey | cut -d ' ' -f 1)

    echo -n "kes.vkey >> "
    echo_yellow "${VKEY}"
    echo
    echo -n "kes.skey >> "
    echo_yellow "${SKEY}"
    echo
    echo

    if ! readYn "ハッシュ値は一致していますか?"; then
        echo_red "キャンセルしました"
        main_menu
    fi

    if ! use_coldkeys; then
        rm "${NODE_HOME}/kes.vkey"
        rm "${NODE_HOME}/kes.skey"
        main_menu
    fi

    while true; do
        clear
        echo
        echo "■ カウンター番号情報"
        echo
        echo "今回更新のカウンター番号: XX"
        echo
        echo "ブロックプロデューサーノードのカウンター番号情報に表示されている、"
        echo "今回更新のカウンター番号を入力してください。"
        
        read -r -p "半角数字で入力してEnterキーを押してください > " counter
        echo

        echo "カウンター番号: '${counter}'"
        echo
        if readYn "上記であっていますか？"; then
        
            unlock_keys

            # shellcheck disable=SC2086
            if ! cardano-cli conway node new-counter \
                --cold-verification-key-file ${COLDKEYS_DIR}/node.vkey \
                --counter-value ${counter} \
                --operational-certificate-issue-counter-file ${COLDKEYS_DIR}/node.counter;
            then
                unuse_coldkeys
                lock_keys

                echo_red "ノードカウンターの更新に失敗しました"
                echo
                echo
                pressKeyEnter "エンターキーを押して再度お試しください"
                return 1
            fi

            lock_keys

            break

        fi

    done

    unlock_keys

    # shellcheck disable=SC2086
    cardano-cli conway text-view decode-cbor \
        --in-file  ${COLDKEYS_DIR}/node.counter \
        | grep int | head -1 | cut -d"(" -f2 | cut -d")" -f1
    
    lock_keys

    
    while true; do

        clear
        echo
        echo "■ 現在のstartKesPeriod"
        echo
        echo "現在のstartKesPeriod: XXXX"
        echo
        echo "ブロックプロデューサーノードに表示されている、"
        echo "現在のstartKesPeriod の値を入力してください。"

        
        read -r -p "半角数字で入力してEnterキーを押してください > " period
        echo

        echo "startKesPeriod: '${period}'"
        echo
        if readYn "上記であっていますか？"; then
        
            cd "$NODE_HOME" || (unuse_coldkeys && return 1)

            unlock_keys

            # shellcheck disable=SC2086
            if ! cardano-cli conway node issue-op-cert \
                --kes-verification-key-file kes.vkey \
                --cold-signing-key-file ${COLDKEYS_DIR}/node.skey \
                --operational-certificate-issue-counter ${COLDKEYS_DIR}/node.counter \
                --kes-period ${period} \
                --out-file node.cert;
            then
                unuse_coldkeys
                lock_keys
                echo
                echo
                echo_red "'node.cert'ファイルの生成に失敗しました"
                echo
                echo
                pressKeyEnter "再度お試しください"
                return 1
            fi

            cp "${NODE_HOME}/node.cert" "$SHARE_DIR/"
            
            unuse_coldkeys
            lock_keys

            clear
            echo
            echo "■ node.cert生成完了"
            echo
            echo "share ディレクトリに node.cert ファイルを出力しました。"
            echo "このファイルをBPのcnodeディレクトリにコピーしてください。"
            echo

            break

        fi

    done

    lock_keys

    rm $SHARE_DIR/kes.vkey
    rm $SHARE_DIR/kes.skey

    echo
    pressKeyEnter "メインメニューに戻るにはEnterキーを押してください"

    main_menu

}


#
# SPO投票
#
vote_spo() {

	clear

    cp "$SHARE_DIR/create_votetx_script" "$NODE_HOME/create_votetx_script"
    cp "$SHARE_DIR/params.json" "$NODE_HOME/params.json"
	SCRIPT_SHA=$(sha256sum "$NODE_HOME/create_votetx_script" | awk '{ print $1 }')
	
    echo 'ハッシュは以下の通りです。'
    echo -n 'ハッシュ値： '
    echo_green "$SCRIPT_SHA"
    echo
    echo
    if ! readYn '次の手順を実行しますか？'; then
        echo_red "操作をキャンセルします"
        echo
        echo
        pressKeyEnter "メニューに戻るにはエンターキーを押してください"
    fi

    
    if ! use_coldkeys; then
        return 1
    fi
    
    # shellcheck disable=SC1091
    # shellcheck disable=SC2086
    source $NODE_HOME/create_votetx_script

    unuse_coldkeys

    mkdir ${SHARE_DIR}/governance
    cp "$NODE_HOME/governance/vote-tx.signed" ${SHARE_DIR}/governance/vote-tx.signed

    rm "$NODE_HOME/governance/vote-tx.signed"
    rm "$NODE_HOME/create_votetx_script"
    rm "$NODE_HOME/params.json"
    rm "$SHARE_DIR/create_votetx_script"
    rm "$SHARE_DIR/params.json"

    echo
    echo_green "'share/governance'ディレクトリ内に、'vote-tx.signed'ファイルを出力しました。"
    echo
    echo
    pressKeyEnter "このファイルをBPに転送し、処理を続行してください"

	main_menu
}


cli_update() {
    clear

    echo "'share'ディレクトリに新しいバージョンのcardano-cliをコピーしてください。"
    pressKeyEnter "コピーができたらEnterキーを押下してください"

    if [ -f "${SHARE_DIR}/cardano-cli" ]; then

        echo '一時フォルダにコピーしています...'
        cp ${SHARE_DIR}/cardano-cli "$HOME/cardano-cli"
        chmod 755 "$HOME/cardano-cli"

        clear
        echo '■ 現在のバージョン'
        cardano-cli version
        echo
        echo '■ 新しいバージョン'
        # shellcheck disable=SC2086
        $HOME/cardano-cli version
        echo
        if readYn "バージョンアップを実行してもよろしいですか？"; then

            echo
            sudo cp "$HOME/cardano-cli" /usr/local/bin/cardano-cli
            sudo chmod 755 /usr/local/bin/cardano-cli
            echo

            rm "$HOME/cardano-cli"
            rm "${SHARE_DIR}/cardano-cli"

            pressKeyEnter "バージョンアップが完了しました！"

        fi
    else
        echo 
        pressKeyEnter -n 1 -p "'${HOST_PWD}/share/cardano-cli'が見つかりませんでした。"
    fi

    main
}


#
# プール報酬出金
#
withdrawal_stake() {

    clear

    echo
    echo "BPにて'tx.raw'を作成後、'share'ディレクトリにコピーしてください。"
    pressKeyEnter "コピーが出来たらEnterキーを押してください。"
    
    if [ ! -f "${SHARE_DIR}/tx.raw" ]; then
        echo
        echo_red "'share'ディレクトリに'tx.raw'ファイルが見つかりませんでした"
        echo
        echo
        pressKeyEnter
        wallet_menu
    fi

    cp ${SHARE_DIR}/tx.raw "$NODE_HOME/tx.raw"

    
    if ! use_coldkeys; then
        rm "${NODE_HOME}/tx.raw"
        wallet_menu
    fi

    cd "$NODE_HOME" || exit
    
    # shellcheck disable=SC2086
    if ! cardano-cli conway transaction sign \
        --tx-body-file tx.raw \
        --signing-key-file payment.skey \
        --signing-key-file stake.skey \
        $NODE_NETWORK \
        --out-file tx.signed;
    then
        unuse_coldkeys

        echo_red "トランザクションファイルへの署名に失敗しました"
        echo
        echo
        pressKeyEnter
        wallet_menu
    fi

    unuse_coldkeys

    cp "${NODE_HOME}/tx.signed" "${SHARE_DIR}/tx.signed"
    rm "${NODE_HOME}/tx.signed"
    rm "${NODE_HOME}/tx.raw"
    rm "${SHARE_DIR}/tx.raw"

    echo_green "トランザクションへの署名が完了しました!"
    echo
    echo
    echo_green "'share'ディレクトリに'tx.signed'ファイルを出力しました。"
    echo
    echo
    pressKeyEnter "このファイルをBPに転送し操作を続行してください"

    wallet_menu
}

#
# payment.addrへの出金
#
withdrawal_stake_to_payment() {

    clear
    echo
    echo_green "gtoolにて作成した'tx.raw'を'share'ディレクトリにコピーしてください"
    echo
    echo
    pressKeyEnter "コピーが出来たらEnterキーを押してください"

    if [ ! -f "${SHARE_DIR}/tx.raw" ]; then
        echo
        echo_red "'share'ディレクトリに'tx.raw'ファイルが見つかりませんでした"
        echo
        echo
        pressKeyEnter
        return 1
    fi

    cd "$NODE_HOME" || exit
    cp "${SHARE_DIR}/tx.raw" "${NODE_HOME}/"

    
    if ! use_coldkeys; then
        rm "${NODE_HOME}/tx.raw"
        return 1
    fi

    if ! cardano-cli conway transaction sign \
        --tx-body-file tx.raw \
        --signing-key-file payment.skey \
        --signing-key-file stake.skey \
        --mainnet \
        --out-file tx.signed;
    then
        unuse_coldkeys
        echo
        echo_red "トランザクションファイルへの署名に失敗しました"
        echo
        echo
        pressKeyEnter
        return 1
    fi

    unuse_coldkeys

    cp "${NODE_HOME}/tx.signed" "${SHARE_DIR}/"
    rm "${NODE_HOME}/tx.signed"
    rm "${NODE_HOME}/tx.raw"
    rm "${SHARE_DIR}/tx.raw"

    echo_green "トランザクションへの署名が完了しました!"
    echo
    echo
    echo_green "'share'ディレクトリに'tx.signed'ファイルを出力しました。"
    echo
    echo
    pressKeyEnter "このファイルをBPに転送し操作を続行してください"

    main
}

#
# 任意のアドレスへ出金(payment.addr)
#
withdrawal_payment() {

	clear
	echo
	echo "gtoolにて作成した'tx.raw'を'share'ディレクトリにコピーしてください"
	echo
	pressKeyEnter "コピーが出来たらEnterキーを押してください"

    if [ ! -f "${SHARE_DIR}/tx.raw" ]; then
        echo
        echo_red "'share'ディレクトリに'tx.raw'ファイルが見つかりませんでした"
        echo
        echo
        pressKeyEnter
        return 1
    fi
	
	cd "${NODE_HOME}" || exit
	cp "${SHARE_DIR}/tx.raw" "$NODE_HOME"/

    
    if ! use_coldkeys; then
        rm "${NODE_HOME}/tx.raw"
        return 1
    fi
    # shellcheck disable=SC2086
	if ! cardano-cli conway transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file payment.skey \
            $NODE_NETWORK \
            --out-file tx.signed;
    then
        unuse_coldkeys
        echo
        echo_red "トランザクションファイルへの署名に失敗しました"
        echo
        echo
        pressKeyEnter
        return 1
    fi

    unuse_coldkeys

	cp "${NODE_HOME}/tx.signed" "${SHARE_DIR}/"
    rm "${NODE_HOME}/tx.signed"
    rm "${NODE_HOME}/tx.raw"
	rm "${SHARE_DIR}/tx.raw"
	
    echo_green "トランザクションへの署名が完了しました!"
    echo
    echo
    echo_green "'share'ディレクトリに'tx.signed'ファイルを出力しました。"
    echo
    echo
    pressKeyEnter "このファイルをBPに転送し操作を続行してください"
}



#
# lib: 暗号化コールドキーを使用したい時に呼び出します
#
use_coldkeys() {

    if ! keys_is_installed; then

        if ! encrypted_keys_exists; then
            echo_red "コールド暗号化キーファイルが見つかりませんでした"
            echo
        else
            if ! decrypt_keys; then
                return 1
            else
                return 0
            fi
        fi
    
    else
        return 0
    fi

    pressKeyEnter "コールドキーが見つかりませんでした"

    return 1
}

#
# lib: 暗号化コールドキーを使用した後に呼び出します
#
unuse_coldkeys() {

    
    if encrypted_keys_exists; then
        
        if check_coldkeys_exists; then
            delete_coldkeys
            return $?
        fi
    fi

    return 1
}


unlock_keys() {
    chmod u+rwx "${COLDKEYS_DIR}"
}

lock_keys() {
    chmod u-rwx "${COLDKEYS_DIR}"
    if [ -f "${NODE_HOME}/vrf.skey" ]; then
        chmod 400 "${NODE_HOME}/vrf.skey"
    fi
    if [ -f "${NODE_HOME}/vrf.vkey" ]; then
        chmod 400 "${NODE_HOME}/vrf.vkey"
    fi
}


#
# コールドキーを暗号化
#
encrypt_keys() {

    if encrypted_keys_exists; then
        echo
        echo_red "すでに暗号化済みのコールドキーが存在しています"
        echo
        pressKeyEnter
        return 1
    fi

    echo

    cd "$HOME" || exit
    unlock_keys

    if ! tar czf ${COLDKEYS_TARBALL} ./cold-keys/node.* ./cnode/payment.{addr,skey,vkey} ./cnode/vrf.{skey,vkey} ./cnode/stake.{addr,skey,vkey}; then
        echo
        echo_red "コールドキーの圧縮に失敗しました"
        echo
        pressKeyEnter
        echo
        return 1
    fi

    # 暗号化
    echo
    echo_green "コールドキーの暗号化に必要なパスワードを入力してください"
    echo
    echo
    if ! openssl enc -aes256 -pbkdf2 -md sha-256 -in ${COLDKEYS_TARBALL} -out ${COLDKEYS_ENCFILE}; then
        echo
        echo_red "コールドキーの暗号化に失敗しました"
        echo
        pressKeyEnter
        echo
        return 1
    fi

    if ! rm "${HOME}/${COLDKEYS_TARBALL}"; then
        echo
        echo_red "コールドキー一時圧縮ファイルの削除に失敗しました"
        echo
        pressKeyEnter
        echo
        return 1
    fi

    if ! delete_coldkeys; then
        echo
        echo_red "平文のコールドキーの削除に失敗しました"
        echo
        echo
        echo_green "コールドキーの暗号化には成功しました"
        echo
        echo
        LS=$(ls -l $COLDKEYS_ENCFILE)
        echo_green "$LS"
        echo
        return 1
    fi

    LS=$(ls -l $COLDKEYS_ENCFILE)
    echo
    echo_green "$LS"
    echo

    return 0
}

delete_coldkeys() {

    cd "$HOME" || exit

    unlock_keys

    if ! rm -f ./cold-keys/node.* ./cnode/payment.{addr,skey,vkey} ./cnode/vrf.{skey,vkey} ./cnode/stake.{addr,skey,vkey}; then
        echo
        echo_red "コールドキーの削除に失敗しました"
        echo
        echo
        pressKeyEnter "再度お試しください"
        echo
        return 1
    fi

    return 0
}

#
# コールドキーを復号化
#  引数1: 何か指定すると元の暗号化ファイルを消さない
#
decrypt_keys() {

    if [ ! -s ${COLDKEYS_ENCFILE} ]; then
        echo_red "暗号化キーファイルが見つかりませんでした"
        echo
        echo
        pressKeyEnter
        return 1 
    fi

    cd "$HOME" || exit

    # 復号化
    echo "暗号化済みコールドキーが見つかりました!"
    echo
    echo_green "コールドキーの復号化に必要なパスワードを入力してください"
    echo
    echo
    
    if ! openssl enc -d -aes256 -pbkdf2 -md sha-256 -in "${COLDKEYS_ENCFILE}" -out "${HOME}/${COLDKEYS_TARBALL}"; then
        echo
        echo_red "コールドキーの復号化に失敗しました"
        echo
        echo
        pressKeyEnter "メニューに戻るにはエンターキーを押してください"
        return 1
    fi

    unlock_keys

    # 展開
    if ! tar xf ${COLDKEYS_TARBALL}; then
        echo
        echo_red "コールドキーの展開に失敗しました"
        echo
        echo
        pressKeyEnter "メニューに戻るにはエンターキーを押してください"
        echo
        rm -f "${HOME}/${COLDKEYS_TARBALL}"
        return 1
    fi

    lock_keys

    rm "${HOME}/${COLDKEYS_TARBALL}"
    rm "${COLDKEYS_ENCFILE}"

    return 0
}


generate_keys_hash() {

    unlock_keys

    IFS=' '
    keys_array=$(get_keys)
    keys=($keys_array)

    COLDKEYS_HASHFILE="${SHARE_DIR}/${COLDKEYS_TARBALL}.txt"
    rm -f "${COLDKEYS_HASHFILE}"

    for i in "${!keys[@]}"; do
        if [ -f "${HOME}${keys[$i]}" ]; then
            HASH=$(sha256sum "${HOME}${keys[$i]}" | cut -d ' ' -f 1)
            echo "${keys[$i]}:${HASH}" >> "${COLDKEYS_HASHFILE}"
        fi
    done

    lock_keys

    echo_green "ハッシュファイルを作成しました。"
    echo
    echo_green "${COLDKEYS_HASHFILE}"
    echo

    return 0
}


verify_keys_hash() {

    unlock_keys

    IFS=' '
    keys_array=$(get_keys)
    keys=($keys_array)

    COLDKEYS_HASHFILE="${SHARE_DIR}/${COLDKEYS_TARBALL}.txt"

    # read "${COLDKEYS_HASHFILE}"
    while read LINE
    do
        FILE=$(echo "${LINE}" | cut -d ':' -f 1)
        FILENAME="${HOME}${FILE}"
        FILEHASH=$(sha256sum "${FILENAME}" | cut -d ' ' -f 1)

        HASH=$(echo "${LINE}" | cut -d ':' -f 2)

#        echo -n "${FILE}"
        printf "%-25s" "${FILE}"
        if [ $HASH = $FILEHASH ]; then
            echo_green "[OK]"
        else
            echo_red "[NG]"
        fi
        echo
    done < "${COLDKEYS_HASHFILE}"

    lock_keys

    return 0
}


#
# メインヘッダーを描画します
#
main_header() {

    clear

    cli_version=$(cardano-cli version | head -1 | cut -d' ' -f2)

    available_disk=$(df -h /usr | awk 'NR==2 {print $4}')

    network=${CARDANO_NODE_NETWORK_ID}

    has_keys="NO"
    emoji_keys=""
    
    if keys_is_installed; then
        has_keys="YES"
        emoji_keys=":unlock:"
    else
        if encrypted_keys_exists; then
            has_keys="ENCRYPT"
            emoji_keys=":lock:"
        fi
    fi
    clear

    if existsGum; then
        gum style --foreground 4 --border double --align center --width 60 --margin "0 1" --padding "1 2" \
            'SPO JAPAN GUILD TOOL for Airgap' "v${CTOOL_VERSION}"
        
        echo -n " {{ Bold \"Network:\" }} {{ Color \"2\" \"\" \"-${network}-\" }}" | gum format --type template
        echo -n " {{ Bold \"CLL:\" }} {{ Color \"3\" \"\" \"${cli_version}\" }}" | gum format --type template
        echo -n " | {{ Bold \"Disk残容量:\" }} {{ Color \"3\" \"\" \"${available_disk}B\" }}" | gum format --type template
        echo -n " | {{ Bold \"Kyes:\" }} {{ Color \"3\" \"\" \"${has_keys}\" }}" | gum format --type template
        echo -n "${emoji_keys}" | gum format --type emoji
        echo
        echo
    else
        echo
        echo -n " >> SPO JAPAN GUILD TOOL for Airgap " && echo_green "ver${CTOOL_VERSION}" && echo " <<"
        echo ' ---------------------------------------------------------------------'
        echo -n " CLI: " && echo_magenta "${cli_version}" && echo -n " | Disk残容量: " && echo_yellow "${available_disk}B" && echo -n " | Keys: " && echo_yellow "${has_keys}"
        echo
        echo
    fi
}


settings_menu() {

    main_header
    if existsGum; then
        menu=$(gum choose --limit 1 --height 10 --header "===== 各種設定 =====" "1. キーをインポート" "2. cardao-cliバージョンアップ" "3. ctoolバージョンアップ" "4. キー暗号化" "5. キー復号化" "6. キーハッシュ生成" "7. キーハッシュ検証" "h. ホームへ戻る" "q. 終了")
        echo " $menu"
        menu=${menu:0:1}
    else
        echo ' -------------------------------------------------'
        echo ' >> 各種設定'
        echo ' -------------------------------------------------'
        echo ' [1] キーをインポート'
        echo ' --------------------------------'
        echo ' [2] cardao-cliバージョンアップ'
        echo ' [3] ctoolバージョンアップ'
        echo ' --------------------------------'
        echo ' [4] キー暗号化'
        echo ' [5] キー復号化'
        echo ' --------------------------------'
        echo ' [h] ホームへ戻る  [q] 終了'
        echo
        # shellcheck disable=SC2162
        read -n 1 -p "メニュー番号を入力してください: > " menu
    fi

    case ${menu} in
        1)
            if check_coldkeys_exists; then
                echo_red "既にコールドキーはインストールされています"
                echo
                echo
                pressKeyEnter
                return 1
            fi
            install_coldkeys
            ;;
        2)
            cli_update
            ;;
        3)
            ctool_update
            ;;
        4)
            clear
            if encrypt_keys; then
                echo_green "コールドキーを暗号化しました"
                echo
                pressKeyEnter
            fi
            settings_menu
            ;;
        5)
            clear
            if decrypt_keys; then
                echo_green "コールドキーを復号化しました"
                echo
                pressKeyEnter
            fi
            settings_menu
            ;;
        6)
            clear
            generate_keys_hash
            pressKeyEnter
            settings_menu
            ;;
        7)
            clear
            verify_keys_hash
            pressKeyEnter
            settings_menu
            ;;
        h)
            main_menu
            ;;
        q)
            echo
            quit
            ;;
        *)
            settings_menu
            ;;
    esac
    settings_menu
}


governance_menu() {

    main_header
    if existsGum; then
        menu=$(gum choose --limit 1 --height 8 --header "===== ガバナンス(登録・投票) =====" "1. SPO投票" "h. ホームへ戻る" "q. 終了")
        echo " $menu"
        menu=${menu:0:1}
    else
        echo ' ------------------------------------------------------------'
        echo ' >> ガバナンス(登録・投票)'
        echo ' ------------------------------------------------------------'
        echo ' [1] SPO投票'
        echo ' --------------------------------'
        echo ' [h] ホームへ戻る  [q] 終了'
        echo
        # shellcheck disable=SC2162
        read -n 1 -p ' メニュー番号を入力してください :> ' menu
    fi
    case ${menu} in
        1)
            vote_spo
            ;;
        h)
            main_menu
            ;;
        q)
            echo
            quit
            ;;
        *)
            governance_menu
            ;;
    esac
}


wallet_menu() {

    main_header
    if existsGum; then
        menu=$(gum choose --limit 1 --height 8 --header "===== ウォレット操作 =====" "1. プール報酬(stake.addr)任意のアドレス(ADAHandle)へ出金" "2. プール報酬(stake.addr)payment.addrへの出金" "3. プール資金(payment.addr)任意のアドレス(ADAHandle)へ出金" "h. ホームへ戻る" "q. 終了")
        echo " $menu"
        menu=${menu:0:1}
    else
        echo ' -------------------------------------------------'
        echo ' >> ウォレット操作'
        echo ' -------------------------------------------------'
        echo -n " "
        echo_magenta ' ■ プール報酬出金(stake.addr)'
        echo
        echo ' [1] 任意のアドレス(ADAHandle)へ出金'
        echo ' [2] payment.addrへの出金'
        echo
        echo -n " "
        echo_magenta ' ■ プール資金出金(payment.addr)'
        echo
        echo ' --------------------------------'
        echo ' [3] 任意のアドレス(ADAHandle)へ出金'
        echo
        echo ' --------------------------------'
        echo ' [h] ホームへ戻る  [q] 終了'
        echo
        # shellcheck disable=SC2162
        read -n 1 -p "メニュー番号を入力してください: > " menu
    fi

    case ${menu} in
        1)
            withdrawal_stake
            wallet_menu
            ;;
        2)
        	withdrawal_stake_to_payment
        	wallet_menu
        	;;
        3)
        	withdrawal_payment
            wallet_menu
        	;;
        q)
            echo
            quit
            ;;
        h)
        	main_menu
        	;;
        *)
            echo
            echo '番号が不正です...'
            sleep 1
            wallet_menu
            ;;
    esac
}


main_menu() {

    main_header
    if existsGum; then
        menu=$(gum choose --limit 1 --height 8 --header "===== メインメニュー =====" "1. ウォレット操作" "2. KES更新" "3. ガバナンス(登録・投票)" "s. 各種設定" "q. 終了")
        echo " $menu"
        menu=${menu:0:1}
    else
        echo ' [1] ウォレット操作'
        echo ' [2] KES更新'
        echo ' --------------------------------'
        echo ' [3] ガバナンス(登録・投票)'
        echo ' --------------------------------'
        echo ' [s] 各種設定'
        echo ' --------------------------------'
        echo ' [q] 終了'
        echo
        # shellcheck disable=SC2162
        read -n 1 -p "メニュー番号を入力してください: > " menu
    fi

    case ${menu} in
        1)
            wallet_menu
            ;;
        2)
            reflesh_kes
            ;;
        3)
        	governance_menu
        	;;
        s)
            settings_menu
            ;;
        q)
            quit
            ;;
        *)
            echo
            echo '番号が不正です...'
            sleep 1
            main
            ;;
    esac
}


main

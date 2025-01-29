#!/bin/bash
set -x -e

for cwcoin in cw_{core,evm,monero,bitcoin,haven,nano,bitcoin_cash,solana,tron,wownero,zano}
do
    if [[ "x$1" == "xasync" ]];
    then
        bash -c "cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd .." &
    else
        bash -c "cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd .."
    fi
done
for cwcoin in cw_{polygon,ethereum,mwebd};
do        
    if [[ "x$1" == "xasync" ]];
    then
        bash -c "cd $cwcoin; flutter pub get; cd .." &
    else
        bash -c "cd $cwcoin; flutter pub get; cd .."
    fi
done

flutter pub get
dart run build_runner build --delete-conflicting-outputs

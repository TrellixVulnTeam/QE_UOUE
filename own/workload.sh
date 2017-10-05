#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# Exit on first error
set -e

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

starttime=$(date +%s)

if [ ! -d ~/.hfc-key-store/ ]; then
	mkdir ~/.hfc-key-store/
fi
cp $PWD/creds/* ~/.hfc-key-store/
# launch network; create channel and join peer to channel
cd ../basic-network
./start.sh

function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

removeUnwantedImages 
# Now launch the CLI container in order to install, instantiate chaincode
# and prime the ledger with our 10 cars
docker-compose -f ./docker-compose.yml up -d cli > /dev/null

# Install example chain code query
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode install -n supplychain -v 1.0 -p github.com/supplychain >/dev/null

# Init the material
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode instantiate -o orderer.example.com:7050 -C mychannel -n supplychain -v 1.0 -c '{"Args":["init","1000","1000","1000", "1000", "2000", "1000","1000","1000","DBS", "1000"]}' -P "OR ('Org1MSP.member','Org2MSP.member')" > /dev/null
sleep 05

# a single arg, providing the iphone ID
function Manufacture() {
  R1="$(($1 * 2))"
  R2="$(($R1 + 1))"

  ARGS='{"Args":["MakeCamera","FrontCam'"$1"'","BackCam'"$1"'","Camera'"$1"'"]}'
  echo "Args: $ARGS"
  # echo "=========================Making Camera=========================="
  docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n supplychain -c '{"Args":["MakeCamera","FrontCam'"$1"'","BackCam'"$1"'","Camera'"$1"'"]}'
  sleep 10

  # Make CPU
  # echo "=========================Making CPU=========================="
  docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n supplychain -c '{"Args":["MakeCPU","ALU'"$1"'","ControlUnit'"$1"'","Register'"$R1"'", "Register'"$R2"'", "CPU'"$1"'"]}'
  sleep 10

  # Make Mainboard
  # echo "=========================Making Mainboard=========================="
  docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n supplychain -c '{"Args":["MakeMainboard","CPU'"$1"'","Memory'"$1"'","SSD'"$1"'", "Mainboard'"$1"'"]}'
  sleep 10

  # Assemble Iphone
  # echo "=========================Assemble IPhone=========================="
  docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" cli peer chaincode invoke -o orderer.example.com:7050 -C mychannel -n supplychain -c '{"Args":["Assemble","Camera'"$1"'","Battery'"$1"'","Mainboard'"$1"'", "IPhone'"$1"'", "Manufacturer'"$1"'"]}'
  sleep 10
}

for i in {1..1000}
do
sleep 0.01
Manufacture $i >/dev/null & 
done

# Manufacture 0 >/dev/null & 
# Manufacture 1 >/dev/null &
# Manufacture 2 >/dev/null &
# Manufacture 3 >/dev/null &
# Manufacture 4 >/dev/null &
# Manufacture 5 >/dev/null & 
# Manufacture 6 >/dev/null &
# Manufacture 7 >/dev/null &
# Manufacture 8 >/dev/null &
# Manufacture 9 >/dev/null &

i=0
for job in $(jobs -p)
do
  wait $job
  if [ $? -ne 0 ]; then
    echo "Cmd $i Job $job fails"
  else
    echo "Cmd $i Job $job finishes"
  fi
   i=$(($i + 1))
done

printf "\nTotal execution time : $(($(date +%s) - starttime)) secs ...\n\n"
STATEDB_SIZE="$(docker exec peer0.org1.example.com  du -s --block-size=K  /var/hyperledger/production/ledgersData/stateLeveldb/ | sed 's/[^0-9]//g')"
echo "State_DB SIZE: $STATEDB_SIZE"
HISTORYDB_SIZE="$(docker exec peer0.org1.example.com  du -s --block-size=K  /var/hyperledger/production/ledgersData/historyLeveldb/ | sed 's/[^0-9]//g')"
echo "History_DB SIZE: $HISTORYDB_SIZE"


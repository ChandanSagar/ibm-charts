#!/bin/bash
#
#################################################################
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2018.  All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
#################################################################
#
# You need to run this once per cluster
#
# Example:
#     ./Cleanup.sh <namespace> [-all]
#

FORCE=""
ALL=""

# Delete pull secret

remove_crfin() {
  crd="$1"
  crdexists=$(kubectl get crd $crd 2>/dev/null)
  if [ "X$crdexists" == "X" ]; then
    return
  fi
  echo "Check for remaining custom resources of type $crd"
  for cr in $(kubectl get -n $NAMESPACE $crd -o name)
  do
    echo "Removing finalizers from $cr"
    kubectl patch -n $NAMESPACE $cr --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 
    echo "Removing $cr"
    kubectl delete -n $NAMESPACE $cr
  done
  echo "Deleting $crd"
  kubectl delete crd $crd
}

NAMESPACE="$1"
case "X$NAMESPACE" in
  X|X--*)
    echo "Usage: $0 <NAMESPACE> [ --all ] [ --force ]"
    exit 1
    ;;
  *)
    ;;
esac
shift

for arg in $*
do
  case $arg in
  --force)
     FORCE="yes"
     ;;
  --all)
     ALL="yes"
     ;;
  esac
done


remove_crfin iscsequences.isc.ibm.com
remove_crfin redis.isc.ibm.com
remove_crfin couchdb.isc.ibm.com
remove_crfin etcd.isc.ibm.com
remove_crfin minio.isc.ibm.com
remove_crfin oidcclient.isc.ibm.com
remove_crfin arangobackuppolicies.backup.arangodb.com
remove_crfin arangobackups.backup.arangodb.com
remove_crfin arangodeploymentreplications.replication.database.arangodb.com
remove_crfin arangodeployments.database.arangodb.com

kubectl delete secret -n $NAMESPACE isc-jwt
kubectl delete secret -n $NAMESPACE isc-helm-account

# deleting arangodb pods
for type in "agnt" "crdn" "prmr"
do
   for pod in $(kubectl get pod -n $NAMESPACE -o name | grep "^pod/arangodb-${type}-")
   do
       kubectl patch -n $NAMESPACE $pod --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 
       kubectl delete -n $NAMESPACE $pod --wait=false
   done
done

# deleting arango secrets
for secret in $(kubectl get secret -n $NAMESPACE -o name |\
    grep "^secret/arango")
do
   kubectl delete -n $NAMESPACE $secret
done

kubectl delete svc -larango_deployment=arangodb -n $NAMESPACE

# Remove license
kubectl delete configmap -n $NAMESPACE ibm-security-foundation-prod-license

if [ "X$ALL" != "X" ]; then
  kubectl delete secret -n $NAMESPACE ibm-isc-pull-secret
  kubectl delete secret -n $NAMESPACE isc-jwt
  kubectl delete secret -n $NAMESPACE isc-helm-account
  kubectl delete scc ibm-isc-scc
fi

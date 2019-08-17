#!/bin/bash

#*********************************************************************************************

###################################
# Bash script to delete pv        #
#                                 #
# V0.0.2.1905   14.08.19          #
#                                 #
# Bash IDE: IntelliJ IDEA         #
#           with plugins          #
#                                 #
###################################

#Knonw bugs ... Prealpha version

#What to do to improve this script ? :
#       https://blog.openshift.com/oc-command-newbies/
#       Use json , yaml to parse value insted grep, awk, cut, etc !!
#       Sometimes umount" exit code !=0
#       Enable script loggings

#*********************************************************************************************


#define global var
#full name of pv that will be deleted:
operation_pv_name="pv-cpq-streaming-platform-kafka-paas-apps-staging-data-3"
clusterid="paas-apps-staging"
project_name="cpq-streaming-platform-kafka"
script_name=$(basename ${0})

#define flags

FORCE_FLAG=0 # Attempt to delete pv if pv not exists in openshift, but created volume exists in openstack

#define var

current_date=$(date +%Y-%m-%d)
current_time=$(date +%H:%m:%S)
log_files=/tmp/"${current_date}"_"${current_time}"_pv_delete.log
current_user=
##########################################################################################
func_print_delimiter()
{
    if [[ $1 != "" ]];
        then
            printf "\n\e[97m*****************************************************************************************************\e[39m"
            printf "\n\e[96m********************$1 .........\e[39m\n"
        else
            printf "\n\n\e[39m"
    fi

}
##########################################################################################

func_ssh_add_ecdsa_host_key()
#Permanently added '......' (ECDSA) to the list of known hosts.
#login to ssh host and exit
{
ssh -o StrictHostKeyChecking=no openshift@$1  exit
}
##########################################################################################
# USAGE FUNCTION
func_usage ()
{
cat << EOF >&2
*************************************************************************************
You should use these parameters:

*************************************************************************************
Usage: $script_name  <pv_name> <clusterid> <force>

- pv            Name of pv
- clusterid     Name of paas-apps | paas-apps7 | paas-apps-staging
- force=yes|no  Attempt to delete pv if pv not exists in openshift, but created volume exists in openstack

example: $script_name "pv-cpq-streaming-platform-kafka-paas-apps-staging-data-3" paas-apps-staging force=no

*************************************************************************************
EOF
}
##########################################################################################

########################################  MAIN block (verifications only...) ####################################

func_usage

if [[ $# != "3" ]]; then echo -e "\e[93mYou must use 3 args...\e[39m" ; exit -1; fi;
if [[ $3 == "force=yes" ]]; then FORCE_FLAG=1; else FORCE_FLAG=0; fi;
if [[ ! $2 =~ ^paas-apps[2,7,8,9]{1}|10|\-staging$ ]]; then echo -e "\e[91mNot existing cloud\e[39m"; exit -14; fi;

operation_pv_name=$1
clusterid=$2

#check tty
if ! $(tty -s)
then
  exit -1
fi

func_print_delimiter "\e[36mStart with force_flag=$FORCE_FLAG"

#check privilage
if [[ `id -u` == "0" ]]; 	then echo -e "\e[91m Run with root privilage not allowed...\e[39m"; exit -1; 	fi;
#check if we can connect to openstack
if [[ -z $OS_PASSWORD ]]; then echo -e "\e[91m Import cloud source file \e[39m" ; exit -1; fi;


#connect to openstack, check tenent, number of unique volumes
func_print_delimiter "\e[36mcheck if this is correct pv, Connect to openstack"
openstack_volume_list=$(openstack volume list -c ID -c Name -c "Attached to" -f value | grep "${operation_pv_name}" )   #
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mThe volume not exists or error is occurred...\e[39m"; exit -1;  fi;

openstack_volume_list_count=$(echo "${openstack_volume_list}" | wc -l)
openstack_pv=$(echo "${openstack_volume_list}" | awk '{print $2}')
openstack_pv_id=$(echo "${openstack_volume_list}" | awk '{print $1}' )
openstack_mounted_node=$(echo "${openstack_volume_list}" | sed 's/\(.\+Attached to \)\(.\+\)/\2/' | awk '{print $1}')
openstack_mounted_pv_device=$(echo "${openstack_volume_list}" | sed 's/\(.\+Attached to.\+on.\+\)\(\/dev\/vd[b-z]\)/\2/'  | awk '{print $1}')

#check if volume has status !="Attached"
echo "${openstack_volume_list}" | grep -i "Attached" 1>/dev/null  2>/dev/null

if [[  `echo $?` != "0" ]];
    then
        echo -e "The volume has not status "Attached". Use command   \e[95mopenstack volume show  "${operation_pv_name}"\e[39m  "
        exit
fi

#echo "${openstack_volume_list}"
#echo "*******************"
#echo "${openstack_pv}"
#echo "${openstack_pv_id}"
#echo "${openstack_mounted_node}"
#echo "${openstack_mounted_pv_device}"
#echo "${openstack_volume_list_count}"



case "${openstack_volume_list_count}"
    in
    0) echo -e "\e[91mThere is no volume "${operation_pv_name}" in this tenant...Exiting... \e[39m" ; exit -1;
    ;;
    1) echo -e "\e[92mThe volume  "${operation_pv_name}" in present... Continue \e[39m " ;
    ;;
    2) echo -e "\e[91mMore than one volumes are exist...Exiting... \e[39m" ; exit -1;
    ;;
    *) echo -e "\e[91mDisk count is $openstack_volume_list_count...Exiting... \e[39m" ; exit -1;
esac


#login to openshift
func_print_delimiter "\e[36m oc login"
oc login https://"${clusterid}".openshift.sdntest.netcracker.com:8443 2> /dev/null
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mAuthentication error is occurred...\e[39m"; exit -1;  fi;

#pv describe
#status_of_pv=0 -exists and mount in openstack
#status_of_pv=1 -not exists and not mount in openstack
func_print_delimiter "\e[36m oc describe pv "${operation_pv_name}""
oc describe pv "${operation_pv_name}" 2>/dev/null
status_of_pv=$(echo $?)

if [[ "${status_of_pv}" != "0" && $FORCE_FLAG == "1" ]];
    then
        func_print_delimiter "\e[93mForce_flag=yes,pv not exists... Try to delete volume in openstack";  #jump to openstack...

    elif [[ "${status_of_pv}" != "0" && $FORCE_FLAG == "0" ]];
        then
            echo -e "\e[91mForce_flag not set, pv will not be deleted, exiting....\e[39m";
         exit -1;
fi;


#if pv exists get parameters
if [[ "${status_of_pv}" == "0" ]];
    then
    openshift_describe_pv=$(oc describe pv "${operation_pv_name}")
    #
    openshift_bind_pv_node=$(echo "${openshift_describe_pv}"  | grep "node=" | cut -d= -f2 )
    openshift_bind_pv_id=$(echo "${openshift_describe_pv}"  | grep "disk-id=" | cut -d= -f2)
    openshift_pv_status=$(echo "${openshift_describe_pv}"  | grep -i "status" | awk '{print $2}')

    echo "openshift_pv_status=$openshift_pv_status"
    #
    echo -e "\e[97mThe pv = \e[101m\e[93m\""${operation_pv_name}"\"\e[97m\e[49m  node-bind=\e[42m$openshift_bind_pv_node\e[49m will be deleted. "
    echo -e "The status of pv is: \e[95m"${openshift_pv_status}"\e[39m"
    func_print_delimiter "\e[36mPress Ctrl+c for break"
    sleep 4
fi

#Additional check openshift/stack : osh.id == ost.id
if [[ $status_of_pv == "0" && $openshift_bind_pv_node != $openstack_mounted_node && $openshift_bind_pv_id != $openstack_pv_id ]];
    then
        echo -e "\e[91mSomething went wrong.(bind_pv_node, bind_pv_id) ..\e[39m";
        exit -1;
fi;
#


########################################  main block (verifications + delete and umount pv from openshift) ####################################
# if pv exists...

if [[ $status_of_pv == "0" ]];
    then

        func_print_delimiter "\e[36moc delete pv"
        oc delete pv "${operation_pv_name}" 2>/dev/null
        func_print_delimiter "\e[36m Exit code=$(echo $?)"

        #if error.... pv not exists ,but we try delete volume in openstack
        ## exit code = 1 - not exists pv  or error

        func_print_delimiter "\e[36m Login to node and add_ecdsa_host_key..."
        func_ssh_add_ecdsa_host_key "$openshift_bind_pv_node"

        func_print_delimiter "\e[36m Login to node and try to umount pv..."

        openshift_mounted_pv_full_format=$(ssh openshift@"${openshift_bind_pv_node}"  sudo df -h | grep "${operation_pv_name}")
        openshift_device_mounted_pv=$(echo "$openshift_mounted_pv_full_format" | awk '{print $1}' | grep -P '^/dev/vd[b-z]$')


        #echo -e "\e[92m$openshift_device_mounted_pv\e[39m"
        #echo -e "\e[39m$openshift_mounted_pv_full_format\e[39m"


        ### $openshift_device_mounted_pv == "" && FORCE_FLAG == "0"  - exit
        ### $openshift_device_mounted_pv == "" && FORCE_FLAG == "1"  - continue do not umount
        ### $openshift_device_mounted_pv != ""  continue and  umount

            if [[ $openshift_device_mounted_pv == "" && $FORCE_FLAG == "0" ]];
            then
                echo -e "\e[91mError  disk not mounted...Exiting...\e[39m";
                exit -1;
                    elif [[ $openshift_device_mounted_pv != ""  ]];
                        then
                            ssh openshift@"${openshift_bind_pv_node}"  sudo umount $openshift_device_mounted_pv
                            current_status=$(echo $?)
            fi;

        if [[ $current_status != "0"  ]]; then echo -e "\e[91m "umount" exit code !=0. Restart this script \e[39m"; exit -1; fi;

        func_print_delimiter "$openshift_device_mounted_pv \e[92m has been  unmounted"

fi


########################################  main block (verifications + deleting volume from openstack) ####################################


func_print_delimiter "\e[36mThe \"openstack server remove volume  "${openstack_mounted_node}" "${openstack_pv_id}" \" is running...."
openstack server remove volume  "${openstack_mounted_node}" "${openstack_pv_id}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mError is occurred...\e[39m"; exit -1;  fi;
func_print_delimiter "\e[92mopenstack server remove was successfull"


func_print_delimiter "\e[36mThe \"openstack volume delete  "${openstack_pv_id}"\" is running...."
openstack volume delete  "${openstack_pv_id}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mError is occurred...\e[39m"; exit -1;  fi;
func_print_delimiter "\e[92mopenstack volume delete was successfull"

#if we there that is delete was sucsessfull
func_print_delimiter "\e[36mStatus OK....\e[39m"





#umount device
#if [[ $openshift_device_mounted_pv !="" ]];
#    then


#read -p "Input \"yes\" to continue...[yes]" tmp_input
#            if [[ $tmp_input != "yes" ]]; then  echo -e "\e[91mExiting....\e[39m"; exit -2; fi;
#echo -e "\e[93mPlease be carefull and input pv id, that will be deleted...\e[39m"
#read  tmp_pv_id;
#
#if [[ $openshift_bind_pv_id != $tmp_pv_id ]]; then echo -e "\e[91mError  id not equal...\e[39m"; exit -1; fi;
#openstack_pv=$(echo $openstack_volume_list | awk '{print $2}' )
#openstack_pv_id=$(echo $openstack_volume_list | awk '{print $1}' )
#openstack_mounted_node=$(echo $openstack_volume_list | sed 's/\(.\+Attached to \)\(.\+\)/\2/' | awk '{print $1}')
#openstack_mounted_pv_device=$(echo $openstack_volume_list | sed 's/\(.\+Attached to.\+on.\+\)\(\/dev\/vd[b-z]\)/\2/'  | awk '{print $1}')

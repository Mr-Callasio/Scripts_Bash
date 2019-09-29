#!/bin/bash 

#/**********************Define color:*************************/

Default=\e[39m
Light_red=\e[91m
Light_green=e[92m
Light_yellow=\e[93m
Light_magenta=\e[95m



#/************************Define functions:************************/

function_check_common_input_value()
{
tmp=$1

	if [[ ! $( echo "$1" | grep -P '^[a-z0-9]{1}[a-z0-9-]+[a-z0-9]{1}$')  ]]; 
		then 
			echo -e "\e[91mThe name = "${tmp}" is incorrect.Or some russian charachters are exist...Exiting\e[39m"; 
			exit -12; 
	fi;
}
#/*********************/
function_check_group_input_value()        # common_function + Big Letters + _ +  space
{
tmp=$1

if [[ ! $(echo "$1" | grep -P '^(?:[\w\-]+[\ ])(?:[\w\-]+[\ ]){0,2}(?:[\w\-]+$)|^(?:[\w\-]+)$' ) ]]; 
		then 
			echo -e "\e[91mThe name \""$1"\" is incorrect...Or some charachters are russian:-) Exiting\e[39m"; 
			exit -12; 

fi;
}
#/**********************/



#/*************************Start input block, checks.....***********************************************************/
# 				void main (void)

#/*******************************************************************************************************************/


#check privilage
if [[ `id -u` == "0" ]]; 	then echo "Run with root privilage not allowed..."; exit -1; 	fi;

#check work dir

if [[ ! -d ~/repo/utils ]]; 	then echo " dir ~/repo/utils does not exists" ; 	exit -1 ; fi;
if [[ ! -d ~/repo/ansible ]]; 	then echo " dir ~/repo/ansible does not exists" ; 	exit -1 ; fi;


#/**********update repo **********************************/

echo -e "\e[36mCheck repo updates....\e[39m"
cd ~/repo/utils

git config --global credential.helper 'cache --timeout=1800'
git pull  --all
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mGIT Error, exiting....\e[39m"; exit -15; fi;

cd ~/repo/ansible
git pull  --all
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mGIT Error, exiting....\e[39m"; exit -15; fi;
#/********************************************************/


#/********************Read cred*******************************/

read -p  "Your openshift login without domain: "  -r openshift_login;
if [[ ! $openshift_login =~ ^[a-zA-Z]{4}[0-9]{4}$ ]];
	then
		echo -e "\e[91mopenshift_login does not match pattern 'ABCD0123'\e[39m"
		exit -10
fi

echo -e  "Your openshift Password: \e[1m{Hidden}\e[8m" ;
read -r -s openshift_password;
echo -e "\e[39m\e[0m"
if [[ -z $openshift_password ]];
	then
		echo "Zero length password...Exiting"
		exit -11
fi

#/**************************************************************/

#/************************read cloud number +9 +10******************/
#read cloud 0,2,7,8,9,10
read -p "Input cloud number[0,2,7,8,9,10]: \"pashift\" - 0, \"pashift2\" - 2 ,\"pashift7\" - 7, \"pashift8\" - 8, \"pashift9\" - 9, \"pashift10\" - 10: "  cloud_number

if  [[ ! $cloud_number =~ ^[0,2,7,8,9]{1}|10$ ]]; then echo -e "\e[91mNot existing cloud\e[39m"; exit -14; fi
#check cloud
case "$cloud_number" 
	in
	0) 	cloud_env="pashift" 
		master_login="pashift-master-1.openshift.local"
		;;
	2) 	cloud_env="pashift2"
		master_login="pashift2-master-1.openshift.local"
		;;
	7) 	cloud_env="pashift7"
		master_login="pashift7-master-1-1.openshift.local"
		;;
	8) 	cloud_env="pashift8"
		master_login="pashift8-master-1-1.openshift.local"
		;;
	9) cloud_env="pashift9"
		master_login="pashift9-master-1-1.openshift.local"
		;;
	10) cloud_env="pashift10"	
		master_login="pashift10-master-1-1.openshift.local"
		;;
esac
	
echo -e "\e[92mcloud=="${cloud_env}"\e[39m"

#/************************************************************************/

#Read account_name, project_name, region
read -p "account_name of project {for example: admin1  }:" -r account_name
function_check_common_input_value "$account_name"

read -p "group_name of project {for example: dev_core_group  }:" -r group_name
function_check_group_input_value "$group_name"

read -p "project_name, {for example: platform-core-ci }:" -r project_name
function_check_common_input_value "$project_name"

read -p "node_selector, {for example: databases }: " -r node_selector
function_check_common_input_value "$node_selector"


#/**************************************************************************/
#Login to cloud and check existing project_account, node_selector, project_name
#check for success auth

echo -e "\e[36mLogging to openshift console...oc login https://"${cloud_env}".openshift.local:8443\e[39m"; 

oc login https://"${cloud_env}".openshift.local:8443 -u $openshift_login -p "${openshift_password}" 1>/dev/null  2>/dev/null

if [[ `echo $?` != "0" ]]; then echo -e "\e[91mAuthentication error, exiting....\e[39m"; exit -15; fi;


#check existing projects...
tmp_project=`oc get project | grep "${project_name}"`
if [[ ! -z "$tmp_project" ]]; 	then 
	echo -e "\e[92mA project  "${project_name}"  exists... Exiting\e[39m";
	exit -20;		
		else echo -e "\e[92mA "${project_name}"  not exists...OK\e[39m";  
fi;

#check if exists account_name
tmp_project_user=`oc get users | grep "${account_name}"`
if [[ -z "${tmp_project_user}" ]]; 
	then 
		echo "This account_name  not exists. Please, create it first ...Exiting" 
		exit -14; 
			else
			echo -e "\e[92mA "${account_name}" exists ...OK\e[39m";
fi;

#check if exists node selector
tmp_node_selector=`oc get nodes --show-labels | grep "${node_selector}"`
if [[ -z "${tmp_node_selector}" ]]; then 
	echo "A node_selector  "${node_selector}"   not exists... Exiting"; 
	exit -21;
		else echo -e "\e[92mA "${node_selector}"  exists ...OK\e[39m";  
fi;

#/**************************************************************/
#check modif date

tmp_diff_second=$1; # 

curr_date_since_epoch=`date +%s`
proj_modif_date=`stat -c %Y /mount/ext_disk/data_openshift`

diff_second=$(( $curr_date_since_epoch - $proj_modif_date ))

proj_modif_date_hr=`stat -c %y /mount/ext_disk/data_openshift | awk '{print $1}' `
proj_time_hr=`stat -c %y /mount/ext_disk/data_openshift | awk '{print $2}'  | cut -d. -f1`

#if_file data_openshift was edited more then 5 minutes ....

if [[ diff_second -gt 300 ]] ; then 
	echo -e "\e[91mDid you edit/save data_openshift ?\e[39m Last modification date $proj_modif_date_hr , $proj_time_hr ....Exiting...." 
	echo "Current date_time: " `date "+%F %T"` 
	exit -16; 
		else echo -e "\e[92mModification date is not too late ...OK\e[39m";
fi

echo -e  "Please, check capacity for new project. If your were checked and project capacity is enought - type \e[94menough\e[39m": 
read -r capacity_enough
if [[ ! $capacity_enough == "enough" ]]; then echo "Exiting...."; fi;

#/*******************End input block.*****************************************************************************/

#/********************Start scripts*****************************************************************************/

#get token
my_temp_token=`oc whoami -t`
#if error - exit
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mToken error , exiting....\e[39m"; exit -15; fi;


echo -e "\e[92mCreate new project at master-node = "${master_login}"\e[39m ... oc adm new-project --admin=$account_name --node-selector="${node_selector}"  "${project_name}"  "
sleep 3
#login to muster node
ssh openshift@"${master_login}"  sudo oc adm new-project --admin="${account_name}" --node-selector="${node_selector}"  "${project_name}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mError creating project , exiting....\e[39m"; exit -15; fi;

#/******************************/

cd ~/repo/utils

echo "run ./restart_qta_and_save.py -c "${cloud_env}" -t "${my_temp_token}"... "
sleep 3
./restart_qta_and_save.py -c "${cloud_env}" -t "${my_temp_token}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mrestart_qta_and_save.py , exiting....\e[39m"; exit -15; fi;


echo "run ./restart_and_set_add_limran.py -c "${cloud_env}" -t "${my_temp_token}"... "
sleep 3
./restart_and_set_add_limran.py -c "${cloud_env}" -t "${my_temp_token}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mrestart_and_set_add_limran.py , exiting....\e[39m"; exit -15; fi;


echo "run ./convert_openshift_prj.py -c "${cloud_env}""
sleep 3
./convert_openshift_prj.py -c "${cloud_env}"
if [[ `echo $?` != "0" ]]; then echo -e "\e[91mconvert_openshift_prj.py , exiting....\e[39m"; exit -15; fi;

#/******************************/

cd ~/repo/ansible

echo "run ./"${cloud_env}"_prmns.sh"
sleep 3
./"${cloud_env}"_prmns.sh
if [[ `echo $?` != "0" ]]; then echo -e "\e[91m${cloud_env}, exiting....\e[39m"; exit -15; fi;

#/*******************************/

#/********************Start checks of projects, account, quotas*****************************************************************************/

whoisadmin=`oc get rolebindings -n "${project_name}" |   egrep '^admin' | awk {'print $3'} `
#whoiseditor=`oc get rolebindings -n "${project_name}" |   egrep '^edit' | sed  's/\/\?edit//g' `
whoiseditor=`oc get rolebindings -n "${project_name}" |   egrep '^edit' | awk '{print $3 $4 $5 $6}' `

requsted_memory_only_digit=`oc describe quota -n "${project_name}" | grep requests.memory | awk {'print $3+0'}`
requsted_memory_only_power=`oc describe quota -n "${project_name}" | grep requests.memory | awk {'print $3+0'} | tr -cd '[:alpha:]'`

requsted_cpu=`oc describe quota -n "${project_name}" | grep requests.cpu | awk {'print $3+0'}`

requsted_storage_digit_only=`oc describe quota -n "${project_name}" | grep requests.storage | awk {'print $3+0'}`
requsted_storage_digit_power=`oc describe quota -n "${project_name}" | grep requests.storage | awk {'print $3+0'} | tr -cd '[:alpha:]'`


if [[ "${whoisadmin}" != "${account_name}" || "${whoiseditor}" != "${group_name}" ]];
then
	echo -e "\e[91mProject admin  got value = "${whoisadmin}",    expected = "${account_name}" "
	echo -e "\e[91mProject edit  got value =  "${whoiseditor}",   expected = "${group_name}"  "
	echo -e "\e[91mProject creation error....Check roles, bindings....\e[39m";
	exit -100
fi			

printf "\e[92mProject was created successfully\e[39m\n\r";
printf "admin == \e[96m$account_name\e[39m,  edit == \e[96m$group_name\e[39m\n\r";
echo "----------------Requested resources-----------------------------"
printf "Requsted_memory = \e[96m"$requsted_memory_only_digit"\e[39m\n\r"
printf "Requsted_cpu = \e[96m"$requsted_cpu"\e[39m\n\r"
printf "Requsted_storage = \e[96m"$requsted_storage_digit_only"\e[39m\n\r"

echo "----------------------------------------------------------------"

oc describe project  "${project_name}" 
oc get rolebindings -n "${project_name}"
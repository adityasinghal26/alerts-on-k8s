#!/bin/bash

# Setting Path for running the scripts
PATH=/home/adityasinghal/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setting 2 log files details (one for last alert and another for temp alert)
file="/home/adityasinghal/alerts/logs/avgcpu.log"
file_temp="/home/adityasinghal/alerts/logs/avgcpu_temp.log"

# Getting change timestamp for last alert log file
last_file_change=$(stat -c '%Z' $file)
echo -e $last_file_change

# Clearing temp alert file
> $file_temp

# Updating Cluster Context (provided as script argument) and setting variables
kubectl config use-context $1
namespace=$2
timestamp=$(date "+%Y-%m-%d %T")
threshold=80              # threshold in percentage which once crossed, will be alerted
realert=295               # time (in seconds) after which next alert mail will be sent, in case of continuous breach
flag=0                    # flag to whether alert needs to be sent or not

# Insert alert text in temp file
echo -e "App TOPS $1 Alert generated at $timestamp UTC \n" >> $file_temp
echo -e "Average CPU utilization for specific deployments \n" >> $file_temp
echo -e "    Deployment \t \t :    Current Usage \n" >> $file_temp

# Get the output of the hpa command
hpa_output=$(kubectl -n $namespace get hpa -o json)

# Get the number of deployments
num_deployments=$(echo $hpa_output | jq -r '.items | length')

# Create arrays for the deployment name, and average CPU usage
declare -a deployment
declare -a usage

# Loop through the deployments and fill the arrays for deployment name and their usage
for ((i=0;i<$num_deployments;i++)); do
    deployment[$i]=$(echo $hpa_output | jq -r ".items[$i].metadata.name")
    usage[$i]=$(echo $hpa_output | jq -r ".items[$i].status.currentMetrics[1].resource.current.averageUtilization")
done

# Iterate over the deployment array and output usage for each deployment
for ((i=0;i<$num_deployments;i++)); do
    d=${deployment[$i]}
    use=${usage[$i]}
    if [ "$use" -gt "$threshold" ] && [ $d != amqdep ] && [ $d != amqmsgdep ] && [ $d != amqoutdep ] && [ $d != amqcrwdep ] && [ $d != amqcrwmsgdep ] && [ $d != amqcrwoutdep ] && [ $d != cacheserverdep ];then
    echo -e "    $d \t \t :    $use% " >> $file_temp
    flag=1
  fi
done

# Get current file timestamp and calculate the change time difference between old and new file
curr_file_change=$(date +"%s")
change=$((curr_file_change-last_file_change))

# Generating the final output and whether to send mail or not
echo "Threshold Crossover Flag is " $flag
if [ "$change" -gt "$realert" ] && [ "$flag" == 1 ]; then
  echo "YES, mail will be sent since change timing is " "$change"
  cp $file_temp $file
  cat $file | mail -s "APP $1 Alert: Average CPU over $threshold%" adityasinghal@gmail.com
elif [ "$change" -lt "$realert" ] && [ "$flag" == 1 ]; then
  echo "NO, mail will not be sent since change timing is " "$change"
elif [ "$flag" == 0 ]; then
  echo "FLAG for threshold cross is " "$flag"
fi



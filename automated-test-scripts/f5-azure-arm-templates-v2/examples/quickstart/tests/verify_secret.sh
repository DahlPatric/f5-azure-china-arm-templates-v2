#  expectValue = "SUCCESS"
#  scriptTimeout = 3
#  replayEnabled = true
#  replayTimeout = 10


if [[ "<CREATE SECRET>" == "True" ]]; then
    # SSH login for <ADMIN USERNAME> is set when we provision the instances, the actual admin user password is configured by runtime init
    TMP_DIR='/tmp/<DEWPOINT JOB ID>'
    SSH_KEY=${TMP_DIR}/<RESOURCE GROUP>-private
    PASSWORD=$(az vm show -g <RESOURCE GROUP> -n <RESOURCE GROUP>-bigip-vm-01 | jq -r .vmId)
    SSH_PORT='22'
    if [[ <NIC COUNT> -eq 1 ]]; then
        MGMT_PORT='8443'
    else
        MGMT_PORT='443'
    fi

    if [[ <PROVISION PUBLIC IP> == False ]]; then
        BASTION_HOST=$(az vm list-ip-addresses -g <RESOURCE GROUP> -n <RESOURCE GROUP>-bastion-vm-01 | jq -r .[0].virtualMachine.network.publicIpAddresses[0].ipAddress)
        echo "Host: $BASTION_HOST"
        IP=$(az deployment group show -g <RESOURCE GROUP> -n <RESOURCE GROUP> | jq -r '.properties.outputs["bigIpManagementPrivateIp"].value')
        echo "IP: $IP"
        ssh-keygen -R ${BASTION_HOST} 2>/dev/null
        VAULT_RESPONSE=$(ssh -o "StrictHostKeyChecking no" -i $SSH_KEY -o ProxyCommand="ssh -o 'StrictHostKeyChecking no' -i $SSH_KEY -W %h:%p azureuser@${BASTION_HOST}" admin@"${IP}" "bash -c 'cat /config/cloud/vault_url'")
        SECRET_RESPONSE=$(ssh -o "StrictHostKeyChecking no" -i $SSH_KEY -o ProxyCommand="ssh -o 'StrictHostKeyChecking no' -i $SSH_KEY -W %h:%p azureuser@${BASTION_HOST}" admin@"${IP}" "bash -c 'cat /config/cloud/secret_id'")
    else
        IP=$(az deployment group show -g <RESOURCE GROUP> -n <RESOURCE GROUP> | jq -r '.properties.outputs["bigIpManagementPublicIp"].value')
        echo "IP: $IP"
        ssh-keygen -R ${IP} 2>/dev/null
        VAULT_RESPONSE=$(ssh -o "StrictHostKeyChecking no" -i $SSH_KEY admin@${IP} -p $SSH_PORT "bash -c 'cat /config/cloud/vault_url'")
        SECRET_RESPONSE=$(ssh -o "StrictHostKeyChecking no" -i $SSH_KEY admin@${IP} -p $SSH_PORT "bash -c 'cat /config/cloud/secret_id'")
    fi

    if echo ${VAULT_RESPONSE} | grep -q "vault" && echo ${SECRET_RESPONSE} | grep -q "BigIpSecret"; then
        echo "SUCCESS"
    fi
else
    echo "Not creating a secret"
    echo "SUCCESS"
fi
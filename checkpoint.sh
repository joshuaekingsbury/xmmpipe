
if [[ -f "pre_inventory.txt" ]]; then
    mv pre_inventory.txt _pre_inventory.txt
fi  

ls >> pre_inventory.txt
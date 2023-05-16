
if [[ ! -f "pre_inventory.txt" ]]; then
    echo "pre_inventory.txt not found. Aborting cleanup."
    return 1 2> /dev/null || exit 1
fi  

ls >> post_inventory.txt

grep -Fxv -f pre_inventory.txt post_inventory.txt >> diff_inventory.txt

while read -r line
do
    echo "$line"
    rm "$line"
done < "diff_inventory.txt"

rm diff_inventory.txt
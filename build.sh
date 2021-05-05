# To build the README.md file from the template.md file and diagrams/* run:
#  
# ./build.sh

DIAGRAMS=$(dirname $(realpath $0))/diagrams
TEMPLATE=$(dirname $(realpath $0))/template.md
README=$(dirname $(realpath $0))/README.md

cp $TEMPLATE $README

for file in $DIAGRAMS/*; do
  name=$(basename $file)
  diagram=$(cat $file)
  sed -i "s/$name/${diagram//$'\n'/\\n}/g" $README
done

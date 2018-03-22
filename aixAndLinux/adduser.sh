#!/bin/bash
counter=1
id=701
while [ ! $counter -gt 150 ]
do
 printf "stu%.3d::$id:$id::/home/stu%.3d:/bin/bash\n" counter counter
 counter=$[counter+1]
 id=$[id+1]
done

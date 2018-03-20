

##2.

You are given two non-empty linked lists representing two non-negative integers. The digits are stored in reverse order and each of their nodes contain a single digit. Add the two numbers and return it as a linked list.

You may assume the two numbers do not contain any leading zero, except the number 0 itself.

>Input: (2 -> 4 -> 3) + (5 -> 6 -> 4)
Output: 7 -> 0 -> 8
Explanation: 342 + 465 = 807.


思路,单个位加然后考虑进位情况

```go
func addTwoNumbers(l1 *ListNode, l2 *ListNode) *ListNode {

	result:=&ListNode{}
	temp:=result
	now,next:=0,0
	for{
		next,now=addListNode(l1,l2,next)
		temp.Val=now
        l1=nextNode(l1)
		l2=nextNode(l2)
		if l1==nil&&l2==nil{
			break
		}
		temp.Next=&ListNode{}
		temp = temp.Next

	}
	if next!=0{
		temp.Next=&ListNode{Val:next}
	}
	return result
}
func nextNode(l *ListNode) *ListNode {
	if l != nil {
		return l.Next
	}
	return nil
}

func addListNode(l1,l2 *ListNode,before int) (int,int) {
	sum:=0
	sum+=before
	if l1!=nil{
		sum+=l1.Val
	}
	if l2!=nil{
		sum+=l2.Val
	}
	now:=sum % 10
	next:= int(sum/10)
	return next,now
}
```


#3  Longest Substring Without Repeating Characters

Given a string, find the length of the longest substring without repeating characters.

Examples:

Given "abcabcbb", the answer is "abc", which the length is 3.

Given "bbbbb", the answer is "b", with the length of 1.

Given "pwwkew", the answer is "wke", with the length of 3. Note that the answer must be a substring, "pwke" is a subsequence and not a substring.


思路,用一个map记录某个字符在上次出现的位置,如果下次出现,则可以得到一个记录,并保存最长记录(如果全部只出现一次,则为数组)


```go
func lengthOfLongestSubstring(s string) int {
	recordings:=make(map[int]int,len(s))
	left,res:=0,0
	for i:=0;i<len(s);i++{
		sint := int(s[i])
		lastIndex,exist:=recordings[sint]
		if exist {
			//出现过,证明recordings[sint]到i已经重复了,非重复起点left右移动
			if recordings[sint]>=left{
				left=lastIndex+1
			}
		}
        //更新最大距离
		if i+1-left>res {
			res = i + 1 - left
		}
        //更新记录
		recordings[sint]=i
		}
	return res
}
```

##4. Median of Two Sorted Arrays

There are two sorted arrays nums1 and nums2 of size m and n respectively.

Find the median of the two sorted arrays. The overall run time complexity should be O(log (m+n)).

Example 1:
nums1 = [1, 3]
nums2 = [2]

The median is 2.0
Example 2:
nums1 = [1, 2]
nums2 = [3, 4]

The median is (2 + 3)/2 = 2.5



思路:归并排序然后求中位数:


```go
func findMedianSortedArrays(nums1 []int, nums2 []int) float64 {
	len1,len2:=len(nums1),len(nums2)
	 resArray :=make([]int,len1+len2)
	j,k:=0,0
	for i:=0;i<len(resArray);i++{
		if j==len1 ||
			( j <len1 && k<len2 && nums2[k]<=nums1[j]){
			resArray[i]=nums2[k]
			k++
			continue
		}
		if k==len2 ||
			(j <len1 && k<len2 && nums2[k]>nums1[j]){
				resArray[i]=nums1[j]
				j++
		}
	}

	midIndex:=(len1+len2)/2 -1
	if (len1+len2)%2==0{
		return float64(resArray[midIndex]+resArray[midIndex+1])/2.0
	}else {
		return float64(resArray[midIndex+1])
	}

}

```





##6. ZigZag Conversion

The string "PAYPALISHIRING" is written in a zigzag pattern on a given number of rows like this: (you may want to display this pattern in a fixed font for better legibility)

P   A   H   N
A P L S I I G
Y   I   R
And then read line by line: "PAHNAPLSIIGYIR"
Write the code that will take a string and make this conversion given a number of rows:

string convert(string text, int nRows);
convert("PAYPALISHIRING", 3) should return "PAHNAPLSIIGYIR".



就是让输入字符走之字形:




```go
func convert(s string, numRows int) string {
	var nbytes [9999][]byte
	nowRow:=0
	flag:=true
	for i:=0;i<len(s);i++{
		nbytes[nowRow] = append(nbytes[nowRow],s[i])
		if numRows!=1{
			if flag{
				if nowRow!=numRows-1{
					nowRow++
				}else {
					flag=!flag
					nowRow--
				}
			}else {
				if nowRow!=0{
					nowRow--
				}else {
					flag=!flag
					nowRow++
				}
			}
		}

	}
	var stringArray []string
	for i:=0;i<numRows;i++{
		stringArray=append(stringArray,string(nbytes[i]))
	}

	return strings.Join(stringArray,"")
}

```


##7  Reverse Integer
Given a 32-bit signed integer, reverse digits of an integer.

Example 1:

Input: 123
Output:  321
Example 2:

Input: -123
Output: -321
Example 3:

Input: 120
Output: 21
Note:
Assume we are dealing with an environment which could only hold integers within the 32-bit signed integer range. For the purpose of this problem, assume that your function returns 0 when the reversed integer overflows.

```go
func reverse(x int) int {
	var positive = 1
	if x<0{
		positive=-1
	}
	temp:=0
	chain:=int(math.Abs(float64(x)))
	for{
		if chain<=0{
			break
		}
		byte:=chain % 10
		temp= temp*10+byte
		chain/=10
	}
	res:=temp * positive
	if res>math.MaxInt32 || res<math.MinInt32{
		return 0
	}else {
		return res
	}
}
```


##9 Palindrome Number
回文数
Determine whether an integer is a palindrome. Do this without extra space.


思路:负数先返回flase,然后int转字符串,在每一位插入'#'(用来解决奇偶问题),然后从中间位起,两个往两边,如果不相等返回错误:


```go
func isPalindrome(x int) bool {
    if x<0{
		return false
	}else {

		str:=DealwithStr(strconv.FormatInt(int64(x),10))
		pos:=len(str)/2
		index:=0
		for{
			if str[pos-index]!=str[pos+index]{
				return false
			}
			index++
			if pos==index {
				break
			}

		}
		return true
	}
}
func DealwithStr(s string) string {
	var strbytes []byte
	for i:=0;i<len(s) ;i++  {
		strbytes =append(strbytes,'#')
		strbytes =append(strbytes,s[i])
	}
	strbytes =append(strbytes,'#')
	return string(strbytes)

}
```


##10.Regular Expression Matching正则

题目:Implement regular expression matching with support for '.' and '*'.

>'.' Matches any single character.
'\*' Matches zero or more of the preceding element.

>
The matching should cover the entire input string (not partial).
>
The function prototype should be:
bool isMatch(const char \*s, const char\*p)
Some examples:
>
isMatch("aa","a") → false
isMatch("aa","aa") → true
isMatch("aaa","aa") → false
isMatch("aa", "a\*") → true
isMatch("aa", ".\*") → true
isMatch("ab", ".\*") → true
isMatch("aab", "c\*a\*b") → true


我们注意到\*并不是完全通配符,而是0个或者1个前一个字符.


###思路:
这题可以采用动态规划来做:
思想:当前符号是否匹配,取决于前面是否匹配与当前的状态


动态方程:

设dp[i,j]二维数组的含义是s[0:i]与p[0:j]是否匹配(bool值)

那么,我们可以来看动态转移方程:

* if p[j]==s[i],当前状态匹配,则dp[i][j]=dp[i-1][j-1]
* if p[j]=='.',表示当前匹配一个任意字符,则dp[i][j]=dp[i-1][j-1]
* if p[j]=='*',表示匹配一个或者多个p前一字符,那么我们需要回去看p[j-1]
    * if p[j-1]==s[i],则当前匹配成功,dp[i][j]=dp[i][j-2]
    * if p[j-1]!=s[i],则当前匹配不成功,dp[i][j]=下面三者的或值
        * dp[i-1][j] 这个情况下,'a\*'匹配多个a
        * dp[i][j-1],这个情况下,'a\*'只匹配一个a
        * dp[i][j-2] 这个情况下,'a\*'匹配空字符

dp数组的填写依赖于i-1,j-1这种上,左的值,那么先填写第一行,再从左到右,从上到下依次填写dp的值
        
代码中,我们取下标1为dp的开始,

```go
func isMatch(s string, p string) bool {

	var dp [500][500]bool
	//空与空是匹配的
	dp[0][0]=true
	//默认无开头是'*'的情况,所以出现通配符,必须前一个匹配当前状态才能匹配(匹配0个的情况)
	for i:=0;i<len(p);i++{
		if p[i]=='*' && dp[0][i-1]{
			dp[0][i+1]=true
		}
	}
	for i:=0;i<len(s);i++{
		for j:=0;j<len(p);j++{
			if p[j]=='.'{
				dp[i+1][j+1]=dp[i][j]
			}
			if p[j]==s[i]{
				dp[i+1][j+1]=dp[i][j]
			}
			if p[j]=='*'{
				if p[j-1]!=s[i] && p[j-1]!='.'{
					dp[i+1][j+1]=dp[i+1][j-1]
				}else {
					dp[i+1][j+1]= (dp[i][j+1] || dp[i+1][j] || dp[i+1][j-1])
				}

			}
	}
	}
	return dp[len(s)][len(p)]
}
```



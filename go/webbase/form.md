##简介

表单的获取:

通过request.ParseForm()解析form后,然后依次获取:


```go
	r.ParseForm()
	fmt.Println("username:",r.Form["username"])
		fmt.Println("password:",r.Form["password"])
		
		//r.Form[""]提取出来的是一个[]string类型
```


如:

```go
package main


import (

	"net/http"
	"log"

	"fmt"
	"html/template"
	"strings"
	"os"
	"reflect"
)

func sayHelloName(w http.ResponseWriter,r *http.Request)  {
	r.ParseForm()
	fmt.Println(r.Form)
	fmt.Println("path",r.URL.Path)
	fmt.Println("scheme",r.URL.Scheme)
	for k,v:=range r.Form{
		fmt.Println("key",k)
		fmt.Println("val",strings.Join(v,""))
	}
	fmt.Fprintf(w,"hello!!!")
}
func login(w http.ResponseWriter,r *http.Request)  {
	r.ParseForm()
	fmt.Println("method:",r.Method)
	if r.Method =="GET"{
		t,_:=template.ParseFiles("./src/template/login.html")
		t.Execute(w,nil)

	}else {
		fmt.Println(r.Form)
		username:=r.Form["username"]
		fmt.Println(reflect.TypeOf(username))
		fmt.Println("username:",r.Form["username"])
		fmt.Println("password:",r.Form["password"])
	}
}

func main() {

	fmt.Println(os.Getwd())
	http.HandleFunc("/",sayHelloName)
	http.HandleFunc("/login",login)
	err:=http.ListenAndServe(":9090",nil)
	if err!=nil{
		log.Fatal(err)
	}

}

```


```html5
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Title</title>
</head>
<body>
<form action="/login" method="post">
    用户名:<input type="text" name="username">
    密码:<input type="password" name="password">
    <input type="submit" value="登陆">
</form>
</body>
</html>
```



###验证表单输入:


用正则去验证中文,数字,邮箱,手机号码等:


```go
//数字:
getint,err:=strconv.Atoi(r.Form.Get("age"))
if m, _ := regexp.MatchString("^[0-9]+$", r.Form.Get("age")); !m {
    return false
}
//中文:
if m, _ := regexp.MatchString("^\\p{Han}+$", r.Form.Get("realname")); !m {
    return false
}
//英文
if m, _ := regexp.MatchString("^[a-zA-Z]+$", r.Form.Get("engname")); !m {
    return false
}
//手机号码:
if m, _ := regexp.MatchString(`^(1[3|4|5|8][0-9]\d{4,8})$`, r.Form.Get("mobile")); !m {
    return false
}
```


下拉菜单的验证:

```go

/*
<select name="fruit">
<option value="apple">apple</option>
<option value="pear">pear</option>
<option value="banane">banane</option>
</select>
*/

slice:=[]string{"apple","pear","banane"}

for _, v := range slice {
    if v == r.Form.Get("fruit") {
        return true
    }
}
return false
```


单选框:

```go
/*
<input type="radio" name="gender" value="1">男
<input type="radio" name="gender" value="2">女
*/
slice:=[]int{1,2}

for _, v := range slice {
    if v == r.Form.Get("gender") {
        return true
    }
}
return false
```

###预防跨站脚本:

表单输入中防止攻击者输入JavaScript、VBScript、 ActiveX或Flash等代码,


手段:

*   验证所有输入数据，有效检测攻击
*   对所有输出数据进行适当的处理，以防止任何已成功注入的脚本在浏览器端运行

用html/template包的转义函数,将输入字段有效转义:

* func HTMLEscape(w io.Writer, b []byte) //把b进行转义之后写到w
* func HTMLEscapeString(s string) string //转义s之后返回结果字符串
* func HTMLEscaper(args ...interface{}) string //支持多个参数一起转义，返回结果字符串 


```go
	str:=template.HTMLEscapeString(strings.Join(r.Form["username"],""))
	fmt.Fprintf(w,str)
```

![](http://orh99zlhi.bkt.clouddn.com/2018-03-05,10:43:48.jpg)


###防止多次上传信息:
解决方案是在表单中添加一个带有唯一值的隐藏字段,在验证表单的时候,先检查带有唯一表单是否已经提交,如果是,拒绝提交

思路:
    redis存储 一个队列,每次已经处理的md5值放入队列中,然后下次提交检查队列中是否有该md5值,redis队列5分钟内清楚一次(即5分钟内不允许重复提交数据)
    md5值的获取:
    
    ```go
    	current :=time.Now().Unix()
		h:=md5.New()
		io.WriteString(h,strconv.FormatInt(current,10))
		token:=fmt.Sprintf("%x",h.Sum(nil))
		fmt.Println(token)
		t,_:=template.ParseFiles("./src/template/login.html")
		t.Execute(w,token)
    ```
    
    
####文件上传:


表单上传中,要添加form的enctype属性:

* application/x-www-form-urlencoded   表示在发送前编码所有字符（默认）
* multipart/form-data      不对字符编码。在使用包含文件上传控件的表单时，必须使用该值。
* text/plain      空格转换为 "+" 加号，但不对特殊字符编码。


```go


/*
<form action="/upload" method="post" enctype="multipart/form-data">
    文件:<input type="file" name="uploadfile">
    <input type="submit" value="upload">
    <input type="hidden" name="token" value="{{.token}}">
</form>
*/
func upload(w http.ResponseWriter,r *http.Request)  {
	fmt.Println("method:",r.Method)
	if r.Method=="GET"{
	token:=getTimeMd5()
	t,_:=template.ParseFiles("./src/template/login.html")
	t.Execute(w,token)
	}else {
		r.ParseMultipartForm(32<<20)
	
		file,handler,err:=r.FormFile("uploadfile")
		if err!=nil{
			fmt.Println(err)
			return
		}
		defer file.Close()
		fmt.Fprintf(w,"%v",handler.Header)
		f,err:=os.OpenFile("./"+handler.Filename,os.O_WRONLY|os.O_CREATE,0666)
		if err!=nil{
			fmt.Println(err)
			return
		}
		defer f.Close()
		io.Copy(f,file)


	}
}
```

*   利用r.ParseMultipartForm()解析上传的form
* file,handler,err:=r.FormFile("uploadfile")获取上传的名字为upload的文件
* 开个文件io,然后copy到新文件中


    
    


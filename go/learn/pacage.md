#标准包的使用

##regexp包

正则包:

简单的模式:

```go
ok,_:=regexp.Match(pt.[]byte(searchIn))
```


编译正则表达式与替换:

```go
package main
import "fmt"
import (
    "regexp"
)
func main() {

re()

}

func re()  {
    searchIn:="John: 2578.34 William: 4567.23 Steve: 5632.18"
    pat := "[0-9]+.[0-9]+"

    if ok,_:=regexp.Match(pat,[]byte(searchIn));ok{
        fmt.Println("Mathch Found!");
    }

    re,_ :=regexp.Compile(pat);
    str := re.ReplaceAllString(searchIn,"##.#")
    fmt.Println(str)
}
```


##结构体:

定义方式:

```go
type mystruct struct {
    in string
} 
func main() {
 var t mystruct;
 t.in ="sds";
 
}
```

```go
 var t mystruct;
 //指针声明
 var p *mystruct;
 p.in="dsfsd";
 t.in ="sds";

```


结构体的内存分布:

```go
//两种声明方式:
type Rect1 struct {Min, Max Point }
type Rect2 struct {Min, Max *Point }
```

![](http://orh99zlhi.bkt.clouddn.com/2018-03-01,15:23:36.jpg)


###内嵌结构体
在一个结构体中嵌入一个结构体类型的匿名字段,形成内嵌结构体与继承(内嵌与组合).

```go
type innerS struct {
    in1 int
    in2 int
}
type outerS struct {
    b int
    c float32
    innerS
}
func main() {
    outer:=new(outerS);
    outer.b=2
    outer.c=3.21;
    outer.in1=4;
    outer.in2=5;
    fmt.Println(outer)
    outer2 :=outerS{1,3.5,innerS{1,2}}
    fmt.Println(outer2)

}


输出:

&{2 3.21 {4 5}}
{1 3.5 {1 2}}
```


###方法:
一个类型加上它的方法等价于面向对象中的一个类。一个重要的区别是：在 Go 中，类型的代码和绑定在它上面的方法的代码可以不放置在一起，它们可以存在在不同的源文件，唯一的要求是：它们必须是同一个包的。


定义方法的一般格式:

```go
func (recv receiver_type) methodName(parameter_list) (return_value_list) { ... }
```

receiver就像面对对象语言中的this或者self,代表了 把该方法绑定在那个结构体上

```go
type TwoInts struct {
    a,b int
}

func main() {

    two1 :=new(TwoInts)
    two1.a=1
    two1.b=2
    fmt.Println(two1.AddThem())
}
func (self *TwoInts) AddThem() int {
    return self.a + self.b;

}
```


当接收对象不是一个结构体的时候:

```go
type Intvector []int
func main() {
    ints := Intvector{1,2,3,4,5,6}

    fmt.Println(ints.Sum())
}
func (self Intvector) Sum() int {
    s:=0;
    for _,x :=range self{
        s+=x;

    }
    return s
}
```




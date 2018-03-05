



##defer

关键字 defer 允许我们推迟到函数返回之前（或任意位置执行 return 语句之后）一刻才执行某个语句或函数


```go
import "fmt"

func main() {
	function1()
}

func function1() {
	fmt.Printf("In function1 at the top\n")
	defer function2()
	fmt.Printf("In function1 at the bottom!\n")
}

func function2() {
	fmt.Printf("function2: Deferred until the end of the calling function!")
}
```


当有多个 defer 行为被注册时，它们会以逆序执行（类似栈，即后进先出）：

```go
func f() {
	for i := 0; i < 5; i++ {
		defer fmt.Printf("%d ", i)
	}
}
```


defer原理猜想:将defer后的语句压入一个栈,在return语句运行的时候,先执行栈中的语句,再执行return语句真正的内容


##内置函数:
---|---
close ,管道通信
len,cap, cap返回切片跟map,
new(用于值类型跟用户自定义类型)
make(用于切片map跟管道)
copy/append 用于复制和连接切片



##函数作为参数与回调


```go
func main() {

    callback(2,add)
}
func add(x int,y int)  {
    fmt.Println(x+y)

}

func callback(x int,f func(x int,y int))  {
    f(x,2)

}
```


##匿名与闭包:

表示参数列表的第一对括号必须紧挨着关键字 func，因为匿名函数没有名称。花括号 {} 涵盖着函数体，最后的一对括号表示对该匿名函数的调用。

```go
package main
import "fmt"

func main() {
f()

}
func f()  {

    g:= func(i int) {fmt.Println(i)}
    for i:=0;i<10 ;i++  {
        g(i);

    }

}
```





协程中:





```go
package main

import (
    "time"
    "fmt"

)


func main()  {

    fmt.Println("in main~");
    go longwait()
    go shortwait()
    fmt.Println("About to sleep in main()")
    time.Sleep(10*1e9)
    fmt.Println("At the end of main")
}

func longwait()  {
    fmt.Println("start to longwait")
    time.Sleep(5 * 1e9)
    fmt.Println("longwait stop")
}
func shortwait()  {
    fmt.Println("start to shortwait")
    time.Sleep(2*1e9)
    fmt.Println("end of shortwait")

}


输出顺序:

in main~
About to sleep in main()
start to longwait
start to shortwait
end of shortwait
longwait stop
At the end of main
```

但假如我们把主程序的等待10s去掉,会发现longwait跟shortwait根本没执行:

![](http://orh99zlhi.bkt.clouddn.com/2018-03-03,10:33:15.jpg)

当 main() 函数返回的时候，程序退出：它不会等待任何其他非 main 协程的结束。这就是为什么在服务器程序中，每一个请求都会启动一个协程来处理，server() 函数必须保持运行状态。通常使用一个无限循环来达到这样的目的。

###channel

通道服务于通信的两个目的：值的交换，同步的，保证了两个计算（协程）任何时候都是可知状态。

![](http://orh99zlhi.bkt.clouddn.com/2018-03-03,10:35:25.jpg)

通道的一般声明:

```go
var identifier chan datatype
```

* 通道只能传输一种类型的数据
* 通道实际上是类型化消息的队列,FIFO,


####通信操作符<-

* 发送
**ch<-int1**表示用通道发送变量int1

* 接收:
    * 从通道接收值:int2 = <-ch,表示从通道中提取值到int2中
    * <-ch 可以单独调用获取通道的(下一个值),当前值会被抛弃

```go
package main

import (
    "time"
    "fmt"

)


func main()  {

    fmt.Println("in main~");

    var ch1 chan string
    ch1 =make(chan string)
    go  recvData(ch1)
    go  sendData(ch1)

    time.Sleep(5e9)

}
func sendData(ch chan string)  {
    ch <- "first"
    ch <- "second"
    ch <- "3"


}
func recvData(ch chan string) {
    var recv string
    for{
        recv = <-ch
        fmt.Println(recv)
    }
    fmt.Println("recv end ")
    }
```


在默认情况下,通道是同步且无缓冲的.


####带缓冲的通道:

```go buf := 100
ch1 := make(chan string, buf)
```


通道内可同时容纳100个字符串个数
,在buffer被占满之前,给该通道发送数据s 不会被阻塞的


####给通道使用for


```go
package main

import (
    "fmt"
    "time"
)

func f1(in chan int) {
    fmt.Println(<-in)
}

func main() {
    suck(pump())
    time.Sleep(2e9)
}
func pump()chan int {
    ch:=make(chan int)
    // 开启协程,并往通道中写入内容
    go func() {
        for i:=0;i<4000;i++{
            ch<-i
        }
    }()
    //返回通道
    return ch
}
func suck(ch chan int)  {
    //接收通道后,开始得到通道中的数并打印
    go func() {
        for v:=range ch{
            fmt.Println(v)
        }
    }()
    fmt.Println("suck is done ")

}


输出:

...
到3999

证明对一个chan用for,如果不是在循环内部终结,这个协程就会一直持续下去(除非主程序停止)
```


####通道的方向:


* 只发送var send_only chan<- int 
* 只接收var recv_only <-chan int


我们可以在函数参数声明的时候定义 通道的单方向;

```go
var c = make(chan int) // bidirectional
go source(c)
go sink(c)

func source(ch chan<- int){
	for { ch <- 1 }
}

func sink(ch <-chan int) {
	for { <-ch }
}
```

```go
sendChan := make(chan int)
reciveChan := make(chan string)
go processChannel(sendChan, receiveChan)

func processChannel(in <-chan int, out chan<- string) {
	for inValue := range in {
		result := ... /// processing inValue
	out <- result
	}
}
```




####通道作筛选器的例子:

这是go一个经典的例子,用go的协程与通道实现寻找素数;

```go
package main

import (
    "fmt"


)

//,第一个必须为最小的素数(因为都是拿第一个作为筛选的起点),产生自然数的方法
func generate(ch chan int)  {
    for i:=2;;i++ {
        ch <- i
    }
}

func filter(in,out chan int,prime int)  {
    for{
    //将prime筛选过的数放入out通道中
        i:=<-in
        if i%prime!=0{
            out<-i
        }
    }
}


func main() {

    ch:=make(chan int)
    go generate(ch)
    for{
    //获取第一个2的素数
        prime:=<-ch
        fmt.Print(prime," ")
        
        ch1:=make(chan int)
        //不断进行筛选,先晒不能整除第一个素数的,再依次将后面的素数作为筛选器
        go filter(ch,ch1,prime)
        ch = ch1
    }
}

```

![](http://orh99zlhi.bkt.clouddn.com/2018-03-03,11:57:10.jpg)

其中矩形为每个通道的第一个数作为筛选器,一列的为经过筛选器后的结果


####使用select切换协程


语法:

```go
select {
case u:= <- ch1:
        ...
case v:= <- ch2:
        ...
        ...
default: // no value ready to be received
        ...
}
```

在任何一个case中执行break或者return .select就结束了

select 做的就是：选择处理列出的多个通信情况中的一个。

* 如果都阻塞了，会等待直到其中一个可以处理
* 如果多个可以处理,随机选择一个执行
* 如果没有通道操作可以处理并且写了 default 语句，它就会执行：default 永远是可运行的（这就是准备好了，可以执行）。


```go
package main

import (
    "fmt"
    "time"
)


func  pump1(ch chan int)  {
    for i:=0;;i++{
        ch<- i*2;
    }
}
func pump2(ch chan int)  {
    for i:=0; ;i++  {
        ch<-i +5;

    }
}
func suck(ch1,ch2 chan int)  {
    for{
        select {
        case v:=<-ch1:
            fmt.Printf("rece on chan1 %d\n",v)
        case v:=<-ch2:
            fmt.Printf("recv on chan2 %d\n",v)

        }
    }
}

func main() {

   ch1:=make(chan int);
   ch2:=make(chan int)
   go pump1(ch1)
   go pump2(ch2)
   go suck(ch1,ch2)
   time.Sleep(1e9)
}

```


服务器后台的写法:

```go
func backend() {
	for {
		select {
		case cmd := <-ch1:
			// Handle ...
		case cmd := <-ch2:
			...
		case cmd := <-chStop:
			// stop server
		}
	}
}
```

用无限循环,循环中用select获取并处理数据


####超时与计时器


time.Ticker结构体,指定的时间间隔重复向通道c发送时间值

```go
type Ticker struct {
    C <-chan Time // the channel on which the ticks are delivered.
    // contains filtered or unexported fields
    ...
}

```

用工厂方法创建Ticker:

```go
time.NewTicker(times)
defer ticker.Stop()

times是时间间隔,类型是Duration,单位ns纳秒
```


**After**用于计时:只触发一次

```go

boom := time.After(5e8)
	select {
		case <-boom:
			fmt.Println("BOOM!")
			return
}
```


```go
 var dur time.Duration = 1e9;
    boom:=time.After(5e9);
    tick:=time.NewTicker(dur)
    defer tick.Stop()
    for{
        select {
        case <-tick.C:
            fmt.Printf("tick !\n")
        case <-boom:
            fmt.Printf("boom\n")
            return

        }
    }

/*输出:
tick !
tick !
tick !
tick !
boom

*/
```

协程的恢复模式:
用recover()保证 停掉了服务器内部一个失败的协程而不影响其他协程的工作

```go
func server(workChan <-chan *Work) {
    for work := range workChan {
        go safelyDo(work)   // start the goroutine for that work
    }
}

func safelyDo(work *Work) {
    defer func {
        if err := recover(); err != nil {
            log.Printf("Work failed with %s in %v", err, work)
        }
    }()
    do(work)
}
```






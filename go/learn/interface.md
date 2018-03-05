##


##接口

格式:

```go
type Namer interface {
    Method1(param_list) return_type
    Method2(param_list) return_type
    ...
}
```

接口名字 一般由[e]r后续组成,或者able,或者I开头;



```go
type Shaper interface {
Area() float32
}

type Square struct {
side float32
}

func (sq *Square) Area() float32 {
return sq.side * sq.side
}

func main() {
sq1 := new(Square)
sq1.side = 5

var areaIntf Shaper
areaIntf = sq1
// shorter,without separate declaration:
// areaIntf := Shaper(sq1)
// or even:
// areaIntf := sq1
fmt.Printf("The square has area: %f\n", areaIntf.Area())
}
```


##反射:
反射是用程序检查其所拥有的结构，尤其是类型的一种能力；这是元编程的一种形式。反射可以在运行时检查类型和变量，例如它的大小、方法和 动态 的调用这些方法。



利用reflect.TypeOf 返回被检查对象的类型
reflect.ValueOf返回对象的值

反射通过检查一个接口的值,变量首先被转化成空接口,
接口值包含一个type与value


```go

func main()  {
    var x float64 = 3.4
    fmt.Println("type",reflect.TypeOf(x))
    v:=reflect.ValueOf(x)
    fmt.Println("value:",v)
    fmt.Println("type",v.Type())
}

type float64
value: 3.4
type float64
```



###反射一个结构体:

通过value.NumField来访问结构体内的值:

```go
package main

import (
    "fmt"
    "reflect"
)

type NotknownType struct {
    s1, s2, s3 string
}

func (self NotknownType) String() string {
    return self.s1 + "-" + self.s2 + "-" + self.s3
}
var secret  interface{} = NotknownType{"ada","go","dfsdf"}
func main()  {
   value := reflect.ValueOf(secret)
   typ:=reflect.TypeOf(secret)
   fmt.Println(value)
   fmt.Println(typ)
   knd:=value.Kind()
   fmt.Println(knd)
   for i:=0;i<value.NumField();i++{
       fmt.Println(typ.Field(i).Name,"value is ",value.Field(i))
   }
   fmt.Println(typ.Method(0).Name)
}
```



##go的面对对象:

* 封装:
Go 简化了数据的访问性:
    * 1)包范围内可访问的:通过标识符的首字母小写,(对象只在它所在的包内可见)
    * 2)可导出:标识符的首字母大写(在对象以外也可见)

* 继承:
用组合的方式实现继承,内嵌一个或者更多个字段,多重继承可以通过内嵌多个类型来实现
* 多态:用接口实现



##简介:

Go的http有两个核心功能：Conn、ServeMux


Go为了实现高并发和高性能, 使用了goroutines来处理Conn的读写事件, 这样每个请求都能保持独立，相互不会阻塞，可以高效的响应网络事件。这是Go高效的保证。


```go
c, err := srv.newConn(rw)
if err != nil {
    continue
}
go c.serve()
```
客户端的每次请求都会创建一个Conn，这个Conn里面保存了该次请求的信息，然后再传递到对应的handler，该handler中便可以读取到相应的header信息，这样保证了每个请求的独立性。




####ServvMux定义:


ServvMux的定义:

```go
type ServeMux struct{
mu sync.RWMutex//锁,请求涉及并发处理,需要锁
m map[string]muxEntry // 路由规则，一个string对应一个mux实体，这里的string就是注册的路由表达式
hosts bool//是否在任意的规则中带有host信息
}
```

muxEntry:

```go
type muxEntry struct {
    explicit bool   // 是否精确匹配
    h        Handler // 这个路由表达式对应哪个handler
    pattern  string  //匹配字符串
}
```


Handler是个接口:

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)  // 路由实现器
}
```



简单路由器实现:

```go
func (mux *ServeMux) ServeHTTP(w ResponseWriter, r *Request) {
    if r.RequestURI == "*" {
        w.Header().Set("Connection", "close")
        w.WriteHeader(StatusBadRequest)
        return
    }
    h, _ := mux.Handler(r)
    h.ServeHTTP(w, r)
}
```
如上所示路由器接收到请求之后，如果是*那么关闭链接，不然调用mux.Handler(r)返回对应设置路由的处理Handler，然后执行h.ServeHTTP(w, r)




go http执行过程:

* 首先调用Http.HandleFunc
    * 1 调用了DefaultServeMux的HandleFunc
    * 2 调用了DefaultServeMux的Handle
    * 3 往DefaultServeMux的map[string]muxEntry中增加对应的handler和路由规则
* 其次:
    * 1 实例化Server
    * 2 调用Server的ListenAndServe()
    * 3 调用net.Listen("tcp", addr)监听端口
    * 4 启动一个for循环，在循环体中Accept请求
    * 5 对每个请求实例化一个Conn，并且开启一个goroutine为这个请求进行服务go c.serve()
    * 6 读取每个请求的内容w, err := c.readRequest()
    * 7 判断handler是否为空，如果没有设置handler（这个例子就没有设置handler），handler就设置为DefaultServeMux
    * 8 调用handler的ServeHttp
    * 9  根据request选择handler，并且进入到这个handler的ServeHTTP
    * 10 选择handler:
        * A 判断是否有路由能满足这个request（循环遍历ServerMux的muxEntry）
        * B 如果有路由满足，调用这个路由handler的ServeHttp
        * C 如果没有路由满足，调用NotFoundHandler的ServeHttp






##布局:
 * 框架布局(FrameLayout)

框架布局(FrameLayout)是最简 单的布局方式，所有添加到布局中 的视图都以层叠的方式显示，第一 个加入的视图放在最底层，最后一 个被放在最顶层，上层视图会覆盖 下层视图，该显示方式类似于堆栈， 又可称为堆栈布局

```xml
 <FrameLayout
        android:layout_width="fill_parent"
        android:layout_height="fill_parent">
        <ImageView android:layout_width="fill_parent"
            android:layout_height="wrap_content"
            android:background="@drawable/wuzhiqi"
            android:layout_gravity="center" />
        <ImageView
            android:layout_width="63dip"
            android:layout_height="70dip"
            android:layout_gravity="center"
            android:background="@drawable/ic_launcher_background"/>
    </FrameLayout>
```

##线性布局

线性布局(LinearLayout),最常用的布局方式，分为水 平线性布局和垂直线性布局。 gravity属性用于控制布局中 视图的位置，取值为top、 bottom、left、right、 center_vertical、 center_horizontal和center

##相对布局:

相对布局(RelativeLayout)可以设置 某一视图相对于其它视图的位置， 这些位置包括上、下、左、右， 属性分别是
android:layout_above、 android:layout_below、 android:layout_toLeftOf、 android:layout_toRightOf


```xml
   <RelativeLayout
       android:layout_width="fill_parent"
       android:layout_height="fill_parent">
       <Button
           android:layout_width="wrap_content"
           android:layout_height="wrap_content"
           android:text="button1"
           android:id="@+id/Button1"/>
       <Button android:id="@+id/button2" android:text="Button2"
           android:layout_width="wrap_content"
           android:layout_height="wrap_content"
           android:layout_below="@id/Button1"
          />
   </RelativeLayout>
```

![](http://orh99zlhi.bkt.clouddn.com/2018-03-20,14:15:15.jpg)

###表格布局(TableLayout)

表格布局(TableLayout)可以将 视图按照行列进行排列，一个 表格布局由一个<TableLayout> 和若干个<TableRow>组成


```xml
    <TableLayout
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        >
        <TableRow android:paddingTop="20dp" >
            <ImageView android:src="@drawable/wuzhiqi" />
            <ImageView android:src="@mipmap/ic_launcher" />
        </TableRow>
    </TableLayout>
```

##xml属性:


###android:id:

@id/value:直接引用,必须在R.id类中存在,如果不存在,则无法验证通过
@+id/value,如果不存在,则创建


### android:layout_width,android:layout_height

空间的宽度和高度;

可以设置的属性:

* fill_parent,表示控件的宽度和高度尽量满足父控件的空间,如果在最上层,则充满整个屏幕
* wrap_content,表示满足控件内容的需要
* 准确的像素 ,单位px或者dip.px屏幕像素点,dp类似像素点

###android:layout_margin
用于设置控件到相邻控件或边缘的距离 ，该属性设置四个方向距离，包括Left、Right、Top、Bottom


若想单独设置某一个方向距离，可以使用如下四个属性:

* android:layout_marginLeft
* android:layout_marginRight
* android:layout_marginTop
* android:layout_marginBottom

当两种方法共存的时候,系统优先使用layout_margin属性

###layout_padding
用于设置控件内容在4个方向距离控件 边缘的距离，

单一方向的距离:

* android:layout_paddingLeft
* android:layout_paddingRight
* android:layout_paddingTop
* android:layout_paddingBottom

###android:layout_weight
用于设置控件的均衡布局,指两个或者多个控件要占用等比例的区域，它们所占的 比例不因屏幕方向、屏幕密度或屏幕高度变化而改变，该属 性的设置值必须为正整数，且不加任何单位

android: layout_weight = “1”

###gravity
android:layout_gravity控件位置;
android:gravity控件中内容的位置;

* center_horizontal 水平居中
* center_vertical 垂直居中
* center 水平和垂直两个方向居中
* left 左侧
* right 右侧
* top 顶端
* bottom 底部


属性可以用"I"组合起来

###visibility

当前控件是否可见,

* visible 可见
* invisible,控件不可见，但保留控件位置，相当于完全 透明的控件
* gone 表示控件不可见，也不保留控件的位置

###background:
颜色:#十六进制
图片:@drawable/resourceId



android:focusable，表示当前控件是否可以通过键盘或者轨迹 球获得焦点
android:focusableInTouchMode，表示当触摸一个控件时，是 否可将当前焦点移动到被触摸的控件上






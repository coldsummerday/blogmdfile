

定义一个以预测某个单词的上下文模型:
$$P(context|W_t)$$
损失函数:$J_{min}=1-P(W-t|W_t)$




$$J^{`}(\theta)=\prod_{t=1}^T\prod_{-m<=j<=m}P(W_{t+j}|w_t;\theta)$$

m代表窗口大小


取对数似然最大化:

$J(\theta)=-\frac{1}{T}\sum_{t=1}^{T}\sum_{j=-m}^{m}\log(P(W_{t+j}|W_{t}))$



$P(W_{t+j}|W_{t})$经过softmax得到:$P(o|c)=\frac{exp(U_{o}^{T}V_{c})}{\sum_{w=1}^{V}exp(U_{w}^{T}V_{c})}$

o代表上下文中确切的某一个,c是中间词语.
$U_{o}$对应是上下文的词向量,$V_{c}$是词向量


将$P(o|c)=\frac{exp(U_{o}^{T}V_{c})}{\sum_{w=1}^{V}exp(U_{w}^{T}V_{c})}$用链式法则:


$$\frac{\partial}{\partial V_{c}}*log \frac{exp(U_{o}^{T}V_{c})}{\sum_{w=1}^{V}exp(U_{w}V_{c})}$$

$\frac{\partial}{\partial V_{c}}*\log{exp(U_{o}^{T}V_{c})}-\frac{\partial}{\partial V_{c}}*\log\sum_{w=1}^v{exp(U_{w}^{T}V_{c})}$


第一项:$\frac{\partial}{\partial V_{c}}*\log{exp(U_{o}^{T}V_{c})}$ 中log与exp对消,则剩下$\frac{\partial}{\partial V_{c}}* (U_{o}^{T}V_{c})=U_{o}$


第二项:

把log当做f函数,$\sum exp$部分当做g函数,用链式法则,得:

$$\frac{1}{\sum_{w=1}^{v}exp(U_{w}^{T}V_{c})} * \frac{\partial}{\partial V_{c}}*\sum_{x=1}^{v}\exp(U_{x}^{T}V_{c})$$

链式化简得:
$$\frac{1}{\sum_{w=1}^{v}exp(U_{w}^{T}V_{c})} * \sum_{x=1}^{v}\frac{\partial}{\partial V_{c}}\exp(U_{x}^{T}V_{c})$$



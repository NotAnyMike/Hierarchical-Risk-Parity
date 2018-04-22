# Hierarchical Risk Parity

El modelo utilizado para solucionar el problema de asset alocation fue el hierarchical Risk Parity, este modelo fue propuesto por Marcos Lopez de Prado (["Building Diversified Portfolios that Outperform Out-of-Sample" (2016)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2708678)). En general el modelo utiliza métodos de inteligencia artificial y grafos para solucionar el problema, el modelo se basa en arboles para reconstruir una estructura herárquica para así restringir el movimiento de la solución del problema al existir choques en los pesos de los activos.

La estructura del repositorio es la siguiente. En términos generales se utilizó el modelo de HRP y el benchmark que se utilizó fue el modelo de optimización de portafolios de Markowitz, un modelo de estos optimizando el Sharpe Ratio, el segundo optimiza la volatilidad. La estructura que se acaba de describir está desarrollada en R (en el archivo `Modelo.R`)  y replicada en python para comprobar solides de los algoritmos (en `HRP.ipynb`). En el archivo records.csv se encuentra el data frame explicado las configuraciones de los diferentes portafolios generados como también sus métricas más importantes.

## Razones por las cuales se decidió contruir el mode lo HRP
el modelo soluciona los problemas de markowitz
los datos por tiempo

## How to run it

## Resultados

## Otros modelos utilizados

## Disclaimers

La parte con relación a python, el modelo de markowitz está basada en el código del [este](https://github.com/PyDataBlog/Python-for-Data-Science) repositorio y el código utilizado para hrp se base en el modelo original propuesto por Marcos Lopez de Prado

The algothims are based from [here](http://economistatlarge.com/portfolio-theory/r-optimized-portfolio) in order to model markowitz model and the efficient frontier and [here](https://residualmetrics.com/index.php/featured-home/10-finance-markets/39-testing-the-performance-of-hierarchical-risk-parity-for-portfolio-optimisation-using-jse-shares) which are based on the original concept of MdeLopez and Markovitz with small deviations.

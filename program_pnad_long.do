/* Programa para montar a Pnad Longitudinal

São 3 comandos:

1. pnad_long Ano1 Trimestre1 Ano2 Trimestre 2		/ Ex.: pnad_long 2018 2 2018 3
2. pnad_long_var Trimestre_referência Variável		/ Ex.: pnad_long_var 2 VD4007 
3. pnad_long_fim					/ Ex.: pnad_long_fim

obs.: só funciona se as variaveis longitudinalizadas nao tiverem uma categoria que seja zero. Se tiver, tem que tirar as linhas (estão marcadas):
"replace var_`2'_2t=0 if (var_`2'_2t==.)" l.195					
"replace var_`2'_1t=0 if (var_`2'_1t==.)" l.229

Essas linhas servem para colocar o valor zero no caso em que o morador não tenha respondido à essa variável. Pode colocar outro valor no lugar de zero.



COMANDO #1. pnad_long (declara os anos e trimestres a serem utilizados

1: ano1
2: trimestre1
3: ano2
4: trimestre2


*/

capture program drop pnad_long
program define pnad_long

	set more off
	keep if (((Ano==`1') & (Trimestre==`2')) | ((Ano==`3') & (Trimestre==`4')))
	
	gen tri_aux=Trimestre
	replace Trimestre=1 if ((Ano==`1') & (tri_aux==`2'))
	replace Trimestre=2 if ((Ano==`3') & (tri_aux==`4'))
	drop tri_aux Ano

	***

* CRIAÇÃO DO PAINEL
		
		
	* Sexo (V2007)
		
		label define sexo 1 "Homem" 2 "Mulher", replace
		label values V2007 sexo


	* Faixa etária (V2009)

		recode V2009 		(0/13=0) (14/17=1) (18/24=2) (25/29=3) (30/44=4) (45/60=5) (61/130=6) (else=99), gen(fx_etariaLONG)
		label define fxeL 	0 "Menos de 14 anos" 1 "14 a 18 anos" 2 "18 a 24 anos" 3 "25 a 29 anos" 4 "30 a 44 anos" ///
					5 "45 a 60" 6 "61+" 99 "outros", replace
		label values fx_etariaLONG fxeL


	disp in yellow "Tamanho total da amostra: " 
	disp in yellow _N


	* cria outro banco (projecao) que tem a projeção da população para cada dominio de projeção e junta com o bancao
	preserve
		collapse (sum) V1028, by(Trimestre posest V2007 fx_etariaLONG)
		rename V1028 proj_pop
		tempfile projecao
		save `projecao', replace
	restore


	* cria variavel que conta o numero total de pessoas do dominio de projeção, OCUPAÇÃO e idade
	gen ordem=1
	sort Trimestre posest   V2007  fx_etariaLONG
	by Trimestre posest   V2007  fx_etariaLONG: gen Ntotal = sum(ordem)

	* joga fora quem tá na última entrevista no T-1 ou na 1ª em T=2 - PROCESSO REDUNDANTE, PQ SAIRIA ABAIXO COM A CRIAÇÃO DA VARIÁVEL duas_entrevistas
	drop if ((V1016==5 & Trimestre==1) | (V1016==1 & Trimestre==2))

	disp in yellow "Tamanho da amostra após eliminação de 1ª e 5ª entrevista: "
	disp in yellow _N

	* SELECIONA IDADE NAO IGNORADA
	drop if V20082 == 9999

	disp in yellow "Tamanho da amostra após eliminação de idade ignorada: "
	disp in yellow _N
	
	* cria id: IDENTIFICADOR DE PESSOA
	egen id = group(UPA V1008 V1014 V2003 V2007 V2008 V20081 V20082)
	duplicates report id


	* PRIMEIRO, CRIA VARIÁVEL duas_entrevistas, QUE É 0 SE O INDIVIDUO SÓ FOI IDENTIFICADO EM UMA DAS ENTREVISTAS 
	duplicates tag id, gen(duas_entrevistas)
	
	* coloca o novo peso, em cada um dos trimestres (se só participou de uma entrevista novo_peso=.)
	gen novo_peso=.

	* joga fora quem nao respondeu as duas entrevistas
	keep if (duas_entrevistas==1)

	* cria variavel que conta o numero total de entrevistass realizadas em cada dominio de projeção, sexo e idade
	sort Trimestre posest  V2007  fx_etariaLONG
	by Trimestre posest  V2007  fx_etariaLONG: gen Nentrev = sum(duas_entrevistas)

	* cria outro banco (NN) que tem esses dois valores para cada dominio de projeção

	preserve
		collapse (max) Ntotal Nentrev, by(Trimestre posest  V2007  fx_etariaLONG)
		rename (Ntotal Nentrev) (Nt Ne)
		tempfile NN
		save `NN', replace
	restore

	* junta com o banco que tem os tamanhos da amostra total (Ntotal) e de entrevistados (Nentrev) e 
	merge m:1 Trimestre posest  V2007  fx_etariaLONG using `NN'
	keep if _merge==3
	drop _merge

	* junta com o banco que tem a projeção da população para cada domínio de projeção, sexo e idade
	merge m:1 Trimestre posest  V2007  fx_etariaLONG using `projecao'
	keep if _merge==3
	drop _merge

	replace novo_peso = V1028 * (Nt/Ne)

	* cria outro banco (pop) que tem a população calculada para cada dominio de projeção
	preserve
		collapse (sum) novo_peso, by(Trimestre posest  V2007  fx_etariaLONG)
		rename novo_peso pop_amostra
		tempfile pop
		save `pop', replace
	restore

	merge m:1 Trimestre posest  V2007  fx_etariaLONG using `pop'
	keep if _merge==3

	* gera o peso para calibrar com a projeção da população
	gen novo_peso2 = novo_peso * (proj_pop/pop_amostra)
	
end
	

	****
	
	


/*

COMANDO #2: pnad_long_var (declara as variáveis a serem longitudinalizadas. Tem que declarar uma por vez)

1: referência (T1 = 1; T2 = 2)
2: variável
*/


capture program drop pnad_long_var
program define pnad_long_var

	set more off
	
	* gera variavel com referencia
	

		if (`1'==1) {
		
			cap: gen ref=`1'
			
			if ref!= `1' {
				disp in red " "
				disp in red "ERRO:"
				disp in red "Trimestre de referência deve ser igual para todas as variáveis"
			}
	
			else {
			
				disp " *** "
				disp in yellow "REFERÊNCIA: T=1"

				* declara a variável de painel e de série temporal
				tsset id Trimestre

				* coloca o mesmo peso (do primeiro trimestre) para o primeiro e o segundo trimestres
				cap: gen peso_ts=L1.novo_peso2
				replace peso_ts=novo_peso2 if (peso_ts==.)

				cap: gen Estrato_ts=L1.Estrato
				replace Estrato_ts=Estrato if (Estrato_ts==.)

				* desenho amostral
				svyset  UPA [pweight =  peso_ts], strata(Estrato_ts) singleunit(centered)

				* variável em 2T
				gen var_`2'_2t=F1.`2'
				replace var_`2'_2t=0 if (var_`2'_2t==.)
			}

		} 
		else if (`1'==2) {
		
			cap: gen ref=`1'
			
			if ref!= `1' {
				disp in red " "
				disp in red "ERRO:"
				disp in red "Trimestre de referência deve ser igual para todas as variáveis"
			}
	
			else {
			
				disp " *** "
				disp in yellow "REFERÊNCIA: T=2"

				* declara a variável de painel e de série temporal
				tsset id Trimestre

				* coloca o mesmo peso (do segundo trimestre) para o primeiro e o segundo trimestres
				cap: gen peso_ts=F1.novo_peso2
				replace peso_ts=novo_peso2 if (peso_ts==.)

				cap: gen Estrato_ts=F1.Estrato
				replace Estrato_ts=Estrato if (Estrato_ts==.)

				* desenho amostral
				svyset  UPA [pweight =  peso_ts], strata(Estrato_ts) singleunit(centered)
				
				* variável em 1T
				gen var_`2'_1t=L1.`2'
				replace var_`2'_1t=0 if (var_`2'_1t==.)
			}

		} 
		else { 
			disp in red " 						"
			disp in red "ERRO:"
			disp in red "Referência deve ser 1 para T1 ou 2 para T2!"
		}	
	

end


	***
	
	
* COMANDO #3: pnad_long_fim (finaliza a longitudinalização. Não contém nenhum argumento. Mas depois de executado, não dá pra acrescentar mais variáveis)

capture program drop pnad_long_fim
program pnad_long_fim
	* mantém só a linha de referência
	keep if Trimestre==ref
	* joga fora variáveis auxiliares
	drop ordem Ntotal duas_entrevistas novo_peso Nentrev Nt Ne proj_pop pop_amostra _merge ref novo_peso2

end


/* 

* TESTE 1

clear all
cd "/mnt/hdexterno/bancos/Bases Não Identificadas/PNAD/PNADC_Trimestral/"
use "PNADC_1T12_4T18.dta"

* roda o programa
do "/mnt/stata/gmonteiro/Input/program_pnad_long.do"

pnad_long 2018 2 2018 3

pnad_long_var 2 VD4010

pnad_long_var 1 VD4009 / erro de tri divergente
pnad_long_var 3 VD4009 / erro de tri inexistente
pnad_long_var 2 VD4009 / ok

pnad_long_var 3 VD4007 / erro de tri inexistente
pnad_long_var 1 VD4007 / erro de tri divergente
pnad_long_var 2 VD4007 / ok

pnad_long_var 2 VD4016 / ok

pnad_long_fim 

preserve
	keep if VD4002==1
	svy linearized: tab var_VD4007_1t VD4007, format(%15,1fc)  count cv
	table var_VD4007_1t  VD4007 [pweight=peso_ts], format(%15,0fc) row col
restore




* TESTE 2

clear all
cd "/mnt/hdexterno/bancos/Bases Não Identificadas/PNAD/PNADC_Trimestral/"
use "PNADC_1T12_4T18.dta"

* roda o programa
do "/mnt/stata/gmonteiro/Input/program_pnad_long.do"

pnad_long 2018 2 2018 3
pnad_long_var 1 VD4007
pnad_long_fim 

preserve
	keep if VD4002==1
	svy linearized: tab var_VD4007_2t VD4007, format(%15,1fc)  count cv
	table var_VD4007_2t  VD4007 [pweight=peso_ts], format(%15,0fc) row col
restore



* TESTE 3

clear all
cd "/mnt/hdexterno/bancos/Bases Não Identificadas/PNAD/PNADC_Trimestral/"
use "PNADC_1T12_4T18.dta"

* roda o programa
do "/mnt/stata/gmonteiro/Input/program_pnad_long.do"

pnad_long 2017 4 2018 1
pnad_long_var 1 VD4007
pnad_long_fim 

preserve
	keep if VD4002==1
	svy linearized: tab var_VD4007_2t VD4007, format(%15,1fc)  count cv
	table var_VD4007_2t  VD4007 [pweight=peso_ts], format(%15,0fc) row col
restore


* TESTE 4

clear all
cd "/mnt/hdexterno/bancos/Bases Não Identificadas/PNAD/PNADC_Trimestral/"
use "PNADC_1T12_4T18.dta"

* roda o programa
do "/mnt/stata/gmonteiro/Input/program_pnad_long.do"

pnad_long 2017 3 2018 3
pnad_long_var 1 VD4007
pnad_long_fim 

preserve
	keep if VD4002==1
	svy linearized: tab var_VD4007_2t VD4007, format(%15,1fc)  count cv
	table var_VD4007_2t  VD4007 [pweight=peso_ts], format(%15,0fc) row col
restore

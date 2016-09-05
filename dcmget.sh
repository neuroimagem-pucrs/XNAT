#!/bin/bash

AET=LAD_MARFIM
AET_PORT=11112
AEC=PIXSERVERINSCER
PACS_PORT=4200
PACS=marfim.lad.pucrs.br
LOG_CFG=/home/zeosmar/log2file.cfg

echo "###################################################"
echo "## Aviso: Recomenda-se utilizar o 'screen' para  ##"
echo "## fazer o download de imagens devido ao tempo   ##"
echo "## que pode levar. As imagens serão baixadas no  ##"
echo "## diretório dicom criado automaticamente no     ##"
echo "## mesmo local onde o script for executado.      ##"
echo "###################################################"


echo -n "Nome do paciente: "
read paciente
printf "\nPesquisando..."

#OS COMANDOS "findscu" USADOS NESSE SCRIPT LEVAM A FLAG "--log-config" QUE INDICA O CAMINHO ATÉ O ARQUIVO
#"log2file.cfg" QUE FOI EDITADO PARA FAZER COM QUE AO INVÉS DO COMANDO MOSTRAR NO TERMINAL OS RESULTADOS,
#ELE COSPE TUDO DENTRO DE UM ARQUIVO CHAMADO "dcmtk.log" GERADO NO LOCAL ONDE O SCRIPT FOR EXECUTADO.
#ESSA FOI A SOLUÇÃO QUE ENCONTREI JÁ QUE O "findscu" NÃO FUNCIONA DESSA FORMA: "findscu ... >> log.txt" 

findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=PATIENT -k PatientName="$paciente" -k StudyDate -k StudyDescription -k AccessionNumber -k StudyInstanceUID --log-config $LOG_CFG

OLDIFS=$IFS	#ISSO AQUI É NECESSÁRIO SEMPRE QUE EU PRETENDO ATUALIZAR OS ELEMENTOS DE UM ARRAY
IFS=$'\n'	#QUE JÁ CONTEM VALORES NELE... COISA DO BASH, NÃO ME PERGUNTE. NO CASO, O ARRAY "numero"
		#É O QUE PRETENDO ATUALIZAR EM BREVE.

#COLETA DE DADOS DO "dcmtk.log" GERADO
lista_pacientes=($(cat dcmtk.log | sed -n '/(0010,0010)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))
ano_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d | cut -c 1-4))
mes_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d | cut -c 5-6))
dia_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d | cut -c 7-8))
estudo=($(cat dcmtk.log | sed -n '/(0008,1030)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))
#"numero" COLETA OS ACCESSION NUMBERS DOS PACIENTES ENCONTRADOS (SE HOUVER)
numero=($(cat dcmtk.log | sed -n '/(0008,0050)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))
#"UID" COLETA OS "StudyInstanceUID" DOS PACIENTES ENCONTRADOS (ESSE SEMPRE TEM!)
uid=($(cat dcmtk.log | sed -n '/(0020,000d)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))

#PEGA O NÚMERO TOTAL DE PACIENTES ENCONTRADOS
total_pacientes=${#lista_pacientes[@]}


if [[ $total_pacientes == 0 ]]; then
	printf "\nNão existem pacientes com esse nome.\n"
	exit 0
fi

#FUNÇÃO QUE PREENCHE O ARRAY "numero" (QUE DEVERIA CONTER O ACCESSION NUMBER DO PACIENTE) COM "#"
#CASO "numero" ESTEJA VAZIO (ISSO QUER DIZER QUE NÃO FOI REGISTRADO UM ACCESSION NUMBER PARA O
#PACIENTE NO MOMENTO DO EXAME). PEGUEI ESSA FUNÇÃO DO GOOGLE, NÃO ME PERGUNTE.
IFS=$OLDIFS
update_array() {
	x=0
	variavel=$1[@]
	a=("${!variavel}")
	for i in "${a[@]}" ; do
		if [[ $i =~ "value" ]]; then
			declare -g $1[$x]="#######"
		fi
	((x++))
	done
}

update_array numero

#PRINTAÇÃO DE TERMINAL
printf "\n\n%d resultado(s) encontrado(s).\n" "${total_pacientes}"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - #PREENCHE O TERMINAL COM -------
printf "N° %-21s%-12s%-22s%s\n" "NOME" "DATA" "ESTUDO" "NÚMERO"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
#COMO EM BASH OS ARRAYS INICIAM DA POSIÇÃO 0, AQUI EU ENGANO O USUÁRIO PRA PRINTAR
#NO TERMINAL COMO SE INICIASSE COM 1 (O LOOP SÓ SERVE PRA SHIFTAR OS RESULTADOS EM 1)
for (( i=0; i<${total_pacientes}; i++ ));
do
  printf "%d  %-20.20s%3.2s/%2.2s/%-6.4s%-21.21s%8.7s\n" "$((i+1))" "${lista_pacientes[$i]}" "${dia_aquisicao[$i]}" "${mes_aquisicao[$i]}" "${ano_aquisicao[$i]}" "${estudo[$i]}" "${numero[$i]}"
done


printf "\nEscolha um resultado: "
read resultado
((resultado--))	#AQUI EU DESFAÇO A ENGANAÇÃO SE NÃO PEGO O RESULTADO
		#ERRADO. DIMINUO 1 DO RESULTADO ESCOLHIDO PELO USUÁRIO

OLDIFS=$IFS	#COISA DO BASH, É NECESSÁRIO PARA ATUALIZAR ARRAYS COM NOVOS VALORES,
IFS=$'\n'	#NÃO ME PERGUNTE O MOTIVO DO PORQUE ISSO É NECESSÁRIO SEMPRE.

#ESSE IF SÓ SERVE PRA GERAR UM NOVO "dcmtk.log" CONTENDO AS SÉRIES DO PACIENTE ESCOLHIDO.
#E SE O ACCESSION NUMBER CONTEM "#", ELE UTILIZA A OPÇÃO "StudyInstanceUID" PRA IDENTIFICAR
#O EXAME SUJEITO. AMBOS CONTEM A FLAG "SeriesInstanceUID" QUE VAI CUSPIR OUTRO TIPO DE UID
#RESPONSÁVEL POR IDENTIFICAR AS RESPECTIVAS SÉRIES QUE FORAM FEITAS NO EXAME. ISSO VAI SER
#ÚTIL CASO O USUÁRIO DESEJE BAIXAR APENAS UMA SÉRIE EM ESPECÍFICO.

if [[ ${numero[$resultado]} =~ "#" ]]; then
	findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k StudyDate -k StudyDescription -k StudyInstanceUID=${uid[$resultado]} -k SeriesDescription -k SeriesNumber -k SeriesInstanceUID --log-config $LOG_CFG
	numero_paciente=${uid[$resultado]}
else
	findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k StudyDate -k StudyDescription -k AccessionNumber=${numero[$resultado]} -k SeriesDescription -k SeriesNumber -k SeriesInstanceUID --log-config $LOG_CFG
	numero_paciente=${numero[$resultado]}
fi

#COLETA DE DADOS DO "dcmtk.log" GERADO
lista_series=($(cat dcmtk.log | sed -n '/(0008,103e)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))
numero_series=($(cat dcmtk.log | sed -n '/(0020,0011)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))
uid_series=($(cat dcmtk.log | sed -n '/(0020,000e)/p' | cut -sf 2 -d '[' | cut -sf 1 -d ']' | sed 1d))

IFS=$OLDIFS #OLHA ELE DE NOVO, NÃO ME PERGUNTE.

#ESSA PARTE VAI GERAR O ARRAY "lista_series_completo", CONCATENANDO "numero_series" E
#"lista_series". O RESULTADO DISSO É UM ARRAY NESSE MODELO:
# 3  MOTOR
# 1  LOC
# 5  AXI 3D
#SIM, ELE CRIA FORA DE ORDEM, PORQUE NO dcmtk.log ESTÁ FORA DE ORDEM, DEPOIS EU ORDENO.
total_lista_series=${#lista_series[@]}
for ((i=0;i<total_lista_series;i++)); do
    movescu -O -lc $LOG_CFG -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${uid_series[i]}
    lista_imgs[i]=`grep -oP "Remaining Suboperations       :\s+\K\w+"  dcmtk.log`
    lista_imgs_completo[i]="${numero_series[i]} ${lista_imgs[i]}"
    #echo ${lista_imgs[i]}
    lista_series_completo[i]="${numero_series[i]} ${lista_series[i]}"
    lista_uid[i]="${numero_series[i]} ${uid_series[i]}" #ESSA CONCATENAÇÃO SÓ SERVE PRA EU
    #SABER A QUAL "SeriesInstanceUID" PERTENCE A QUAL SÉRIE. O RESULTADO É UM ARRAY ASSIM:
   	# 3 1.2.840.113619.2.312.4120.8416138.29
    	# 1 1.2.840.113619.2.312.4120.8416138.25
  	# 5 1.2.840.113619.2.312.4120.8416138.32
   	#SIM, NA MESMA ORDEM DA CONCATENAÇÃO DE "lista_series", PELO MESMO MOTIVO.
    #ESSE ARRAY VAI SER ÚTIL PARA IDENTIFICAR A SÉRIE QUE O USUÁRIO DESEJAR
    #BAIXAR.
done
IFS=$'\n' lista_uid_ordenado=($(sort -n <<<"${lista_uid[*]}")) #ORDENO O "lista_uid"
IFS=$'\n' lista_imgs_ordenado=($(sort -n <<<"${lista_imgs_completo[*]}")) #ORDENO O "lista_imgs_completo"

#PRINTAÇÃO DE TERMINAL
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
printf "%s - Nº %s\n" "${lista_pacientes[$resultado]}" "${numero_paciente}"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
printf "%s %-20.20s %s\n" "N°" "SÉRIE" "TOTAL DE IMAGENS"
#printf "N° SÉRIE TOTAL DE IMAGENS\n"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
#ORDENO O "lista_series_completo" AGORA
IFS=$'\n' lista_series_completo_ordenado=($(sort -n <<<"${lista_series_completo[*]}"))
#printf "%s\n" "${lista_series_completo_ordenado[@]}"
for i in "${!lista_series_completo_ordenado[@]}"; do 
    printf "%-22.22s %s\n" "${lista_series_completo_ordenado[$i]}" "${lista_imgs_ordenado[$i]:3}"
done

printf "\nO que deseja fazer?\n"
PS3='Escolha uma opção: '
options=("Baixar tudo." "Baixar uma série." "Refazer pesquisa." "Encerrar.")
#ESSAS OPÇÕES PRECISAM SER IGUAIS ÁS DE BAIXO PRA FUNCIONAR DIREITO.
select opt in "${options[@]}"
do
    case $opt in
        "Baixar tudo.")
		mkdir -p dicom
		for i in "${!lista_series_completo_ordenado[@]}"; do
			nome_serie=${lista_series_completo_ordenado[$i]:3}
			mkdir -p dicom/${nome_serie//[[:blank:]]/}
			movescu --log-config $LOG_CFG  -O -aec $AEC -aet $AET --port $AET_PORT \
			-od dicom/${nome_serie//[[:blank:]]/} \
			$PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${lista_uid_ordenado[$i]:3}
		printf "\nDownload Completo\n"
		while true; do
		read -p "Deseja importar para o XNAT?(sim/nao):" optxnat
		case $optxnat in
			sim ) echo "Importando arquivo...";;
			nao ) echo "Encerrando...";exit;;
			* ) echo "Por favor, entre com 'sim' ou 'nao'.";;
		esac
		done

		done
            ;;
        "Baixar uma série.")
		echo -n "Número da série: "
		read numero_serie
		((numero_serie--)) #MESMA JOGADINHA
		nome_serie=${lista_series_completo_ordenado[$numero_serie]:3}
		mkdir -p dicom/${nome_serie//[[:blank:]]/}
		movescu --log-config $LOG_CFG -O -aec $AEC -aet $AET --port $AET_PORT \
		-od dicom/${nome_serie//[[:blank:]]/} \
		$PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${lista_uid_ordenado[$numero_serie]:3}
		#AQUI EU PULO OS 3 PRIMEIRO CARACTERES PARA PEGAR SOMENTE O UID DA SÉRIES.
		#EX: USUÁRIO ESCOLHE A POSIÇÃO 1 (QUE NA VERDADE É 0) E NELA CONTEM:
		#1 1.2.840.113619.2.312.4120.8416138.25
		#A SAÍDA VAI SER APENAS:
		#1.2.840.113619.2.312.4120.8ls416138.25
		printf "\nDownload Completo\n"
		while true; do
		read -p "Deseja importar para o XNAT?(sim/nao):" optxnat
		case $optxnat in
			sim ) echo "Importando arquivo...";;
			nao ) echo "Encerrando...";exit;;
			* ) echo "Por favor, entre com 'sim' ou 'nao'.";;
		esac
		done
            ;;
        "Refazer pesquisa.")
		bash dcmget.sh
            ;;
        "Encerrar.")
		rm dcmtk.log
		break
            ;;
        *) echo Opção inválida;;
    esac
done

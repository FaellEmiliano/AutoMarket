def buscar(mapa, entrega):
    origem = entrega["origem"]
    destino = entrega["destino"]
    largura = len(mapa[0])
    fila = [origem]
    inicio = 0
    pais = {}
    mapa[origem[0]][origem[1]] = 0
    achou = False
    while inicio < len(fila) and not achou:
        atual = fila[inicio]
        inicio = inicio + 1
        if atual[0] == destino[0] and atual[1] == destino[1]:
            achou = True
        else:
            for passo in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
                linha = atual[0] + passo[0]
                coluna = atual[1] + passo[1]
                if linha >= 0 and linha < len(mapa) and coluna >= 0 and coluna < largura:
                    if mapa[linha][coluna] == 1:
                        proxima = [linha, coluna]
                        pais[linha * largura + coluna] = atual
                        fila.append(proxima)
                        mapa[linha][coluna] = 0
    rota = []
    if achou:
        atual = destino
        while atual[0] != origem[0] or atual[1] != origem[1]:
            rota = [atual] + rota
            atual = pais[atual[0] * largura + atual[1]]
        rota = [origem] + rota
    return rota

while True:
    entrega = entrega_atual()
    if entrega:
        mapa = mapa_entrega()
        rota = buscar(mapa, entrega)
        enviar_rota(rota)
    wait(1)

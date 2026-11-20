%% =========================================================================
%% SCRIPT 2: EXPERIMENTO INTERFERENCIA TCP/IP (Wi-Fi 802.11)
%% =========================================================================
clear; clc; close all;

% --- CONFIGURACIÓN DE PARÁMETROS ---
puertoCOM = 'COM3';          % Cambia al puerto COM de tu ESP32 Receptor (Nodo B)
baudios   = 115200;
tiempoGrabarSec = 10;        % Tiempo de grabación por escenario (segundos)

% Escenarios de prueba simulando interferencia de red TCP/IP Wi-Fi
casosTCPIP = {
    'Caso 0: Línea Base (Sin Tráfico TCP/IP)', ...
    'Caso 1: Servidor TCP en Emisor (Contención CSMA/CA en Origen)', ...
    'Caso 2: Servidor TCP en Receptor (Saturación de Banda/ACKs en Destino)', ...
    'Caso 3: Servidor TCP en Punto Medio'
};

datosTCPIP = [];

% --- CONEXIÓN SERIE ---
fprintf('Iniciando conexión para experimento TCP/IP en %s...\n', puertoCOM);
try
    s = serialport(puertoCOM, baudios, "Timeout", 5);
    flush(s);
    fprintf('¡Conexión establecida exitosamente!\n\n');
catch ME
    error('Error al abrir el puerto %s: %s', puertoCOM, ME.message);
end

% --- BUCLE DE CAPTURA DE DATOS ---
for c = 1:length(casosTCPIP)
    nombreCaso = casosTCPIP{c};
    idCaso = c - 1;
   
    fprintf('=========================================================\n');
    fprintf('CONFIGURACIÓN %d de %d (TCP/IP Wi-Fi):\n', c, length(casosTCPIP));
    fprintf('  --> %s\n', nombreCaso);
    fprintf('=========================================================\n');
   
    input('--> Enciende el tráfico TCP/IP y presiona [ENTER] para comenzar...', 's');
   
    fprintf('  [*] Grabando datos TCP/IP durante %d segundos...\n', tiempoGrabarSec);
    flush(s);
   
    datosPunto = [];
    tic;
   
    while toc < tiempoGrabarSec
        if s.NumBytesAvailable > 0
            try
                linea = readline(s);
                valores = str2double(split(linea, ','));
               
                if length(valores) == 8 && ~any(isnan(valores))
                    datosPunto = [datosPunto; idCaso, valores'];
                end
            catch
                continue;
            end
        end
    end
   
    numMuestras = size(datosPunto, 1);
    fprintf('  [✓] Captura completada: %d muestras registradas.\n\n', numMuestras);
    datosTCPIP = [datosTCPIP; datosPunto];
end

clear s;
fprintf('¡Experimento TCP/IP completado exitosamente!\n\n');

% --- GUARDAR DATOS EN CSV Y MAT ---
nombresCols = {'ID_Caso', 'Seq', 'RSSI_dBm', 'Noise_dBm', 'SNR_dB', ...
               'PRR_percent', 'CollisionRate_percent', 'WindowLost', 'TotalCollisions'};
tablaTCPIP = array2table(datosTCPIP, 'VariableNames', nombresCols);

writetable(tablaTCPIP, 'Resultados_Experimento_TCPIP.csv');
save('Resultados_Experimento_TCPIP.mat', 'datosTCPIP', 'tablaTCPIP');
fprintf('Datos exportados a "Resultados_Experimento_TCPIP.csv" y ".mat"\n\n');

% --- GENERACIÓN DE GRÁFICAS COMPARATIVAS ---
etiquetas = {'Base (Sin TCP)', 'TCP en Emisor', 'TCP en Receptor', 'TCP en Mitad'};

snrProm  = arrayfun(@(id) mean(datosTCPIP(datosTCPIP(:,1)==id, 5)), 0:3);
prrProm  = arrayfun(@(id) mean(datosTCPIP(datosTCPIP(:,1)==id, 6)), 0:3);
colProm  = arrayfun(@(id) mean(datosTCPIP(datosTCPIP(:,1)==id, 7)), 0:3);

fig2 = figure('Name', 'Analisis TCP/IP - Impacto de Contencion y Colision', 'Color', [1 1 1]);

% Subplot 1: SNR
subplot(3,1,1);
b1 = bar(snrProm, 'FaceColor', [0.0 0.686 0.784], 'EdgeColor', 'k'); grid on;
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Relación Señal a Ruido bajo Interferencia TCP/IP (SNR)', 'Color', 'k'); ylabel('SNR (dB)', 'Color', 'k');
text(1:4, b1.YEndPoints, string(round(b1.YData, 1)) + " dB", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

% Subplot 2: PRR
subplot(3,1,2);
b2 = bar(prrProm, 'FaceColor', [0.4660 0.6740 0.1880], 'EdgeColor', 'k'); grid on; ylim([0 115]);
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Tasa de Recepción de Paquetes (PRR)', 'Color', 'k'); ylabel('PRR (%)', 'Color', 'k');
text(1:4, b2.YEndPoints, string(round(b2.YData, 1)) + "%", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

% Subplot 3: Collision Rate
subplot(3,1,3);
b3 = bar(colProm, 'FaceColor', [0.6350 0.0780 0.1840], 'EdgeColor', 'k'); grid on; ylim([0 115]);
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Tasa de Colisión y Pérdida por CSMA/CA', 'Color', 'k'); ylabel('Colisiones (%)', 'Color', 'k');
text(1:4, b3.YEndPoints, string(round(b3.YData, 1)) + "%", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

exportgraphics(fig2, 'Grafica_TCPIP_Colisiones.png', 'Resolution', 300);
fprintf('Gráfica de alta resolución guardada como "Grafica_TCPIP_Colisiones.png"\n');

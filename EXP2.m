%% =========================================================================
%% SCRIPT 1: EXPERIMENTO ESP-NOW CON MÉTRICA DE COLISIONES
%% =========================================================================
clear; clc; close all;

% --- CONFIGURACIÓN DE PARÁMETROS ---
puertoCOM = 'COM3';          % Cambia al puerto COM de tu ESP32 Receptor (Nodo B)
baudios   = 115200;
tiempoGrabarSec = 10;        % Tiempo de grabación por escenario (segundos)

% Definición de escenarios de prueba para ESP-NOW
casosESPNOW = {
    'Caso 0: Línea Base (Sin Nodo C)', ...
    'Caso 1: Nodo C al lado del Emisor (Nodo A)', ...
    'Caso 2: Nodo C al lado del Receptor (Nodo B)', ...
    'Caso 3: Nodo C en la Mitad del Enlace'
};

% Matriz de almacenamiento general
% Columnas: [ID_Caso, Seq, RSSI, Noise, SNR, PRR, CollisionRate, WindowLost, TotalCollisions]
datosESPNOW = [];

% --- CONEXIÓN SERIE ---
fprintf('Iniciando conexión con el Receptor ESP-NOW en %s...\n', puertoCOM);
try
    s = serialport(puertoCOM, baudios, "Timeout", 5);
    flush(s);
    fprintf('¡Conexión establecida exitosamente!\n\n');
catch ME
    error('Error al abrir el puerto %s: %s', puertoCOM, ME.message);
end

% --- BUCLE DE CAPTURA DE DATOS ---
for c = 1:length(casosESPNOW)
    nombreCaso = casosESPNOW{c};
    idCaso = c - 1;
   
    fprintf('=========================================================\n');
    fprintf('CONFIGURACIÓN %d de %d (ESP-NOW):\n', c, length(casosESPNOW));
    fprintf('  --> %s\n', nombreCaso);
    fprintf('=========================================================\n');
   
    input('--> Prepara el entorno y presiona [ENTER] para comenzar la captura...', 's');
   
    fprintf('  [*] Grabando datos durante %d segundos...\n', tiempoGrabarSec);
    flush(s);
   
    datosPunto = [];
    tic;
   
    while toc < tiempoGrabarSec
        if s.NumBytesAvailable > 0
            try
                linea = readline(s);
                valores = str2double(split(linea, ','));
               
                % Validar que la trama tenga exactamente los 8 campos CSV del firmware actualizado
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
    datosESPNOW = [datosESPNOW; datosPunto];
end

clear s; % Cerrar puerto serie
fprintf('¡Experimento ESP-NOW completado exitosamente!\n\n');

% --- GUARDAR DATOS EN CSV Y MAT ---
nombresCols = {'ID_Caso', 'Seq', 'RSSI_dBm', 'Noise_dBm', 'SNR_dB', ...
               'PRR_percent', 'CollisionRate_percent', 'WindowLost', 'TotalCollisions'};
tablaESPNOW = array2table(datosESPNOW, 'VariableNames', nombresCols);

writetable(tablaESPNOW, 'Resultados_Experimento_ESPNOW.csv');
save('Resultados_Experimento_ESPNOW.mat', 'datosESPNOW', 'tablaESPNOW');
fprintf('Datos exportados a "Resultados_Experimento_ESPNOW.csv" y ".mat"\n\n');

% --- GENERACIÓN DE GRÁFICAS EN FONDO BLANCO (3 SUBPLOTS) ---
etiquetas = {'Base (Sin C)', 'C en Emisor', 'C en Receptor', 'C en Mitad'};

snrProm  = arrayfun(@(id) mean(datosESPNOW(datosESPNOW(:,1)==id, 5)), 0:3);
prrProm  = arrayfun(@(id) mean(datosESPNOW(datosESPNOW(:,1)==id, 6)), 0:3);
colProm  = arrayfun(@(id) mean(datosESPNOW(datosESPNOW(:,1)==id, 7)), 0:3);

fig1 = figure('Name', 'Analisis ESP-NOW - Interferencia y Colisiones', 'Color', [1 1 1]);

% Subplot 1: SNR
subplot(3,1,1);
b1 = bar(snrProm, 'FaceColor', [0.1176 0.5647 1.0], 'EdgeColor', 'k'); grid on;
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Relación Señal a Ruido (SNR)', 'Color', 'k'); ylabel('SNR (dB)', 'Color', 'k');
text(1:4, b1.YEndPoints, string(round(b1.YData, 1)) + " dB", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

% Subplot 2: PRR
subplot(3,1,2);
b2 = bar(prrProm, 'FaceColor', [0.1333 0.5451 0.1333], 'EdgeColor', 'k'); grid on; ylim([0 115]);
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Tasa de Recepción de Paquetes (PRR)', 'Color', 'k'); ylabel('PRR (%)', 'Color', 'k');
text(1:4, b2.YEndPoints, string(round(b2.YData, 1)) + "%", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

% Subplot 3: Tasa de Colisión (Collision Rate)
subplot(3,1,3);
b3 = bar(colProm, 'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'k'); grid on; ylim([0 115]);
set(gca, 'Color', [1 1 1], 'XColor', 'k', 'YColor', 'k', 'XTickLabel', etiquetas, ...
         'GridColor', [0.2 0.2 0.2], 'GridAlpha', 0.3, 'FontSize', 10, 'FontWeight', 'bold');
title('Tasa de Colisión e Inferencia de Pérdidas', 'Color', 'k'); ylabel('Colisiones (%)', 'Color', 'k');
text(1:4, b3.YEndPoints, string(round(b3.YData, 1)) + "%", ...
     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'k', 'FontWeight', 'bold');

exportgraphics(fig1, 'Grafica_ESPNOW_Colisiones.png', 'Resolution', 300);
fprintf('Gráfica de alta resolución guardada como "Grafica_ESPNOW_Colisiones.png"\n');
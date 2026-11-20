%% SCRIPT DE CAPTURA ITERATIVA POR DISTANCIA EN MATLAB
clear; clc; close all;

% --- CONFIGURACIÓN DE PARÁMETROS ---
puertoCOM = 'COM3';          % Cambia 'COM3' al puerto de tu ESP32 Receptor
baudios   = 115200;
distancias = [10, 20, 30, 40, 50]; % Distancias a evaluar en metros
tiempoGrabarSec = 10;        % Tiempo de grabación en cada punto (segundos)

% Contenedor final de todos los datos [Distancia, Seq, RSSI, Noise, SNR, PRR]
datosExperimento = [];

% --- CONEXIÓN AL PUERTO SERIE ---
fprintf('Iniciando conexión con el ESP32 Receptor en %s...\n', puertoCOM);
try
    s = serialport(puertoCOM, baudios, "Timeout", 5);
    flush(s); % Limpiar el búfer serie previo
    fprintf('¡Conexión exitosa!\n\n');
catch ME
    error('No se pudo abrir el puerto serie: %s. Revisa la conexión.', ME.message);
end

% --- BUCLE DE EXPERIMENTACIÓN ITERATIVO ---
for i = 1:length(distancias)
    distActual = distancias(i);
   
    % Mensaje de pausa para el usuario
    fprintf('=========================================================\n');
    fprintf('PASO %d de %d: Prepara el equipo para la distancia = %d metros.\n', ...
            i, length(distancias), distActual);
    fprintf('=========================================================\n');
   
    % Pausa hasta que el usuario confirme movimiento
    input('--> Ubica los nodos a la distancia indicada y presiona [ENTER] para GRABAR...', 's');
   
    fprintf('  [*] Grabando datos a %dm durante %d segundos...\n', distActual, tiempoGrabarSec);
   
    % Limpiar búfer acumulado durante el tiempo de desplazamiento
    flush(s);
   
    % Estructura temporal para este punto
    datosPunto = [];
    tic; % Iniciar cronómetro para los 10 segundos
   
    while toc < tiempoGrabarSec
        if s.NumBytesAvailable > 0
            try
                % Leer línea enviada por el ESP32
                linea = readline(s);
               
                % Convertir de texto CSV a números [Seq, RSSI, Noise, SNR, PRR]
                valores = str2double(split(linea, ','));
               
                % Validar que la línea tenga exactamente los 5 valores esperados
                if length(valores) == 5 && ~any(isnan(valores))
                    % Guardar con la distancia como primera columna
                    datosPunto = [datosPunto; distActual, valores'];
                end
            catch
                % Ignorar tramas incompletas o errores de lectura
                continue;
            end
        end
    end
   
    % Confirmación de datos guardados en este punto
    numMuestras = size(datosPunto, 1);
    fprintf('  [✓] Captura completada: %d muestras registradas en %dm.\n\n', numMuestras, distActual);
   
    % Acumular en la matriz general
    datosExperimento = [datosExperimento; datosPunto];
end

% --- CIERRA Y DESCONEXIÓN ---
clear s; % Cierra la conexión serie de forma limpia
fprintf('=========================================================\n');
fprintf('  ¡EXPERIMENTO FINALIZADO CON ÉXITO!\n');
fprintf('=========================================================\n');

% --- GUARDAR DATOS EN ARCHIVO MAT Y CSV ---
% Formato de columnas: Distancia, Seq, RSSI, Noise, SNR, PRR
nombresColumnas = {'Distancia_m', 'Seq', 'RSSI_dBm', 'Noise_dBm', 'SNR_dB', 'PRR_percent'};
tablaDatos = array2table(datosExperimento, 'VariableNames', nombresColumnas);

writetable(tablaDatos, 'Experimento_Atenuacion_Distancia.csv');
save('Experimento_Atenuacion_Distancia.mat', 'datosExperimento', 'tablaDatos');
fprintf('Datos guardados en "Experimento_Atenuacion_Distancia.csv" y ".mat"\n\n');

% --- GENERACIÓN AUTOMÁTICA DE GRÁFICAS ---
figure('Name', 'Resultados del Experimento de Distancia', 'Color', [1 1 1]);

% Subgráfica 1: Promedio de SNR por Distancia
subplot(2,1,1);
snrPromedios = arrayfun(@(d) mean(datosExperimento(datosExperimento(:,1)==d, 5)), distancias);
plot(distancias, snrPromedios, '-o', 'LineWidth', 2, 'Color', [0 0.4470 0.7410], ...
     'MarkerFaceColor', [0 0.4470 0.7410], 'MarkerSize', 8);
grid on;
title('Atenuación del SNR según la Distancia');
xlabel('Distancia (m)');
ylabel('SNR Promedio (dB)');

% Subgráfica 2: PRR Promedio por Distancia
subplot(2,1,2);
prrPromedios = arrayfun(@(d) mean(datosExperimento(datosExperimento(:,1)==d, 6)), distancias);
plot(distancias, prrPromedios, '-s', 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980], ...
     'MarkerFaceColor', [0.8500 0.3250 0.0980], 'MarkerSize', 8);
grid on;
ylim([0 105]);
title('Tasa de Recepción de Paquetes (PRR) según la Distancia');
xlabel('Distancia (m)');
ylabel('PRR Promedio (%)');
using GLMakie
using GeometryBasics
using LinearAlgebra 

fig = Figure(size = (2000, 1500))
scene = LScene(fig[1:22, 4:10], show_axis = true)  

cam3d!(scene,
       eyeposition = Vec3f(8, 8, 20),
       lookat = Vec3f(0, 1.5, 0)
      )  

# Definicja parametrów ciała
segment_length = 0.75
arm_length = 0.5
forearm_length = 0.1
thigh_length = 1.0
shin_length = 0.05
hip_height = 1.0
head_radius = 0.1
time_steps = 70
barbell_length = 1.5 
barbell_radius = 0.05  
weight_radius = 0.2   
weight_length = 0.2   
floor_size = 1.0

g = 9.81  # Przyspieszenie ziemskie (m/s²)
mass_human = 70.0  #Masa człowieka (kg)
mass_per_weight_unit = 10.0  #Masa na jednostkę długości talerzy (kg na jednostkę długości)
mass_weight = weight_length * mass_per_weight_unit  # Masa jednego talerza (kg)
mass_total = mass_human + 2 * mass_weight  #Całkowita masa (człowiek + talerze)
delta_t = 0.05  #Definicja delta_t na podstawie czasu trwania snu
previous_velocity = 0.0  #Inicjalizacja poprzedniej prędkości

#Definicja kolorów, przy modelowaniu latwiej bylo rozroznic posczegolne czesci ciala
colors = (:red, :blue, :green, :black, :orange, :purple, :yellow, :cyan, :magenta)

#Dodanie obserwowalnych zmiennych is_running i barbell_visible ktore pomagaja w obsludze przyciskow
is_running = Observable(true)
barbell_visible = Observable(true)
#Licznik powtorzen
rep_count = Observable(0)


# Definicja wierzchołków podłogi
floor_vertices = [
    Point3f0(-floor_size, 0, -floor_size),  # Lewy dolny
    Point3f0(floor_size, 0, -floor_size),   # Prawy dolny
    Point3f0(floor_size, 0, floor_size),    # Prawy górny
    Point3f0(-floor_size, 0, floor_size)    # Lewy górny
]

# Definicja ścianek używając indeksacji 1-based jako płaskiej tablicy , pomoc AI
floor_faces = [
    1, 2, 3,  
    1, 3, 4   
]

#Utworzenie obiektu Mesh dla podłogi
floor_geometry = GeometryBasics.Mesh(floor_vertices, floor_faces)

# Dodanie podłogi do sceny
mesh!(
    scene,
    floor_geometry,
    color = :darkgray,    #Kolor podłogi
    shading = NoShading       
)

#Inicjalizacja części ciała jako obserwowalne zmienne, po poprawnym ,poczatkowym zamodelowaniu czlowieka AI pomoglo wygenerowac zaleznosci miedzy poszczegolnymi czesciami ciala. potrzebowaly one jednak duzo pracy zeby wygladac "realistycznie"
hip = Observable(Point3f0(0, hip_height, 0))

left_foot = Point3f0(-0.3, 0, 0)
right_foot = Point3f0(0.3, 0, 0)

left_thigh_pos = Observable([hip[], left_foot])
right_thigh_pos = Observable([hip[], right_foot])

left_shin_pos = Observable([left_thigh_pos[][2], left_foot])
right_shin_pos = Observable([right_thigh_pos[][2], right_foot])

torso_pos = Observable([hip[], hip[] + Point3f0(0, segment_length, 0)])
torso_top = Observable(Point3f0(0, hip_height + segment_length, 0))

#Pozycje ramion względem górnej części tułowia
shoulder_offset = 0.3
left_shoulder = Observable(torso_top[] + Point3f0(-shoulder_offset, 0, 0))
right_shoulder = Observable(torso_top[] + Point3f0(shoulder_offset, 0, 0))

#Inicjalizacja mostka jako obserwowalna zmienna
bridge_pos = Observable([left_shoulder[], right_shoulder[]])

#Inicjalizacja pozycji ramion jako obserwowalnych zmiennych
left_arm_pos = Observable([left_shoulder[], left_shoulder[] + Point3f0(-arm_length * cos(π / 4), -arm_length * sin(π / 4), 0)])
right_arm_pos = Observable([right_shoulder[], right_shoulder[] + Point3f0(arm_length * cos(π / 4), -arm_length * sin(π / 4), 0)])

#Inicjalizacja pozycji przedramion jako obserwowalnych zmiennych
left_forearm_pos = Observable([left_arm_pos[][2], left_arm_pos[][2] - Point3f0(0, forearm_length, 0)])
right_forearm_pos = Observable([right_arm_pos[][2], right_arm_pos[][2] - Point3f0(0, forearm_length, 0)])

#Inicjalizacja pozycji głowy
head_pos = Observable([torso_top[] + Point3f0(0, head_radius, 0)])

# Inicjalizacja sztangi jako obserwowalnej zmiennej
barbell_central = Observable([left_shoulder[] + Point3f0(-barbell_length / 2, 0, 0),
                              right_shoulder[] + Point3f0(barbell_length / 2, 0, 0)])

# Dodanie centralnej części sztangi
barbell_plot = linesegments!(scene, barbell_central, color = :gray, linewidth = 7)

#Inicjalizacja pozycji lewego i prawego talerza w odniesieniu do pozycji barkow
left_weight_pos = Observable(left_shoulder[] + Point3f0(-barbell_length / 2 - weight_length / 2, 0, 0))
right_weight_pos = Observable(right_shoulder[] + Point3f0(barbell_length / 2 + weight_length / 2, 0, 0))

#Inicjalizacja siatek talerzy jako obserwowalnych zmiennych z wartością nothing
left_weight_mesh = Observable{Union{AbstractPlot, Nothing}}(nothing)
right_weight_mesh = Observable{Union{AbstractPlot, Nothing}}(nothing)

#Dodanie suwaka rozmiaru talerzy
weight_radius_slider = Slider(fig[21, 5:8], range = 0.1:0.01:0.9, width = 200, height = 30)
Label(fig[21, 9:10], text = "Adjust Weight", fontsize = 14, halign = :center)

#Aktualizacja rozmiaru talerzy i zwiazanej z nia masy po zmianie wartości suwaka
on(weight_radius_slider.value) do new_radius
    weight_radius = new_radius 

    #Aktualizacja masy talerza na podstawie nowego promienia
    mass_weight[] = weight_length * mass_per_weight_unit * (new_radius / default_radius)^2

    #Aktualizacja całkowitej masy na podstawie nowej masy talerza
    mass_total[] = mass_human + 2 * mass_weight[]
end

default_radius = 0.2  #Początkowa wartość suwaka to 0.2

#Dynamiczna aktualizacja talerzy przy zmianie pozycji, usuwanie starej siatki i dodawanie nowej
on(left_weight_pos) do pos
    
    if !isnothing(left_weight_mesh[]) && isa(left_weight_mesh[], AbstractPlot)
        delete!(scene, left_weight_mesh[])
        left_weight_mesh[] = nothing  
    end

    
    left_weight_mesh[] = mesh!(
        scene,
        GeometryBasics.Cylinder(
            pos,
            pos + Point3f0(weight_length, 0, 0),
            Float32(weight_radius_slider.value[])  
        ),
        color = :silver
    )
end

on(right_weight_pos) do pos
   
    if !isnothing(right_weight_mesh[]) && isa(right_weight_mesh[], AbstractPlot)
        delete!(scene, right_weight_mesh[])
        right_weight_mesh[] = nothing  
    end

   
    right_weight_mesh[] = mesh!(
        scene,
        GeometryBasics.Cylinder(
            pos,
            pos + Point3f0(-weight_length, 0, 0),
            Float32(weight_radius_slider.value[])  
        ),
        color = :silver
    )
end



#Dodanie segmentów ciała do sceny
linesegments!(scene, left_thigh_pos, color = colors[1], linewidth = 5)
linesegments!(scene, right_thigh_pos, color = colors[2], linewidth = 5)
linesegments!(scene, left_shin_pos, color = colors[3], linewidth = 5)
linesegments!(scene, right_shin_pos, color = colors[4], linewidth = 5)
linesegments!(scene, torso_pos, color = colors[5], linewidth = 5)
linesegments!(scene, bridge_pos, color = :purple, linewidth = 5)
linesegments!(scene, left_arm_pos, color = colors[7], linewidth = 5)
linesegments!(scene, right_arm_pos, color = colors[8], linewidth = 5)
linesegments!(scene, left_forearm_pos, color = colors[9], linewidth = 5)
linesegments!(scene, right_forearm_pos, color = colors[1], linewidth = 5)
meshscatter!(scene, head_pos, markersize = 0.1, color = colors[6])

#widoczności sztangi, pomagala przy animacji
on(barbell_visible) do visible
    if !isnothing(left_weight_mesh[]) && isa(left_weight_mesh[], AbstractPlot)
        left_weight_mesh[][:visible] = visible
    end
    if !isnothing(right_weight_mesh[]) && isa(right_weight_mesh[], AbstractPlot)
        right_weight_mesh[][:visible] = visible
    end
    if !isnothing(barbell_plot) && isa(barbell_plot, AbstractPlot)
        barbell_plot[:visible] = visible
    end
end

# Przycisk Add Barbell
barbell_button = Button(fig[21, 3:4], label = "Toggle barbell", width = 120, height = 30)
on(barbell_button.clicks) do _
    barbell_visible[] = !barbell_visible[]
    println("Barbell visibility: ", barbell_visible[])
end

# Przycisk Start/stop 
button = Button(fig[21, 1:2], label = "Start / Stop", width = 120, height = 30)
on(button.clicks) do _
    is_running[] = !is_running[]  # Przełącz animację
    println("Animation running: ", is_running[])
end

# Inicjalizacja obserwowalnych zmiennych dla parametrow potrzebnych do obliczen
hip_position_y = Observable(hip[][2])  # Współrzędna y biodra
velocity = Observable(0.0)              # Prędkość biodra (m/s)
kinetic_energy = Observable(0.0)        # Energia kinetyczna (J)
generated_power = Observable(0.0)       # Wygenerowana moc (W)
work_done = Observable(0.0)             # Wykonana praca (J)

mass_weight = Observable(weight_length * mass_per_weight_unit * (default_radius)^2)  #masa talerzy liczona jest na podstawie ich promienia
mass_total = Observable(mass_human + 2 * mass_weight[])  #masa czlowieka + masa dwoch talerzy

#Definicja przesunięć dla keypointow twarzy
nose_offset = Point3f0(0, 0, head_radius)  
eye_offset_x = head_radius * 0.5          
eye_offset_y = head_radius * 0.3         
eye_offset_z = head_radius * 0.6          
ear_offset_x = head_radius                
ear_offset_z = -head_radius * 0.5        

#Inicjalizacja kluczowych punktów
#Elementy twarzy sa inicjowane wzgledem srodka glowy
nose = Observable(Point3f0(head_pos[][1][1] , 
                           head_pos[][1][2] , 
                           head_pos[][1][3] + nose_offset[3]))
left_eye = Observable(Point3f0(head_pos[][1][1] - eye_offset_x, 
                                head_pos[][1][2] , 
                                head_pos[][1][3] + eye_offset_z))
right_eye = Observable(Point3f0(head_pos[][1][1] + eye_offset_x, 
                                 head_pos[][1][2] , 
                                 head_pos[][1][3] + eye_offset_z))
left_ear = Observable(Point3f0(head_pos[][1][1] - ear_offset_x, 
                                head_pos[][1][2], 
                                head_pos[][1][3] + ear_offset_z))
right_ear = Observable(Point3f0(head_pos[][1][1] + ear_offset_x, 
                                 head_pos[][1][2], 
                                 head_pos[][1][3] + ear_offset_z))

#Barki sa symetrycznie oddalone wzgledem gory tulowia
left_shoulder = Observable(Point3f0(torso_top[][1] - shoulder_offset, 
                                    torso_top[][2], 
                                    torso_top[][3]))
right_shoulder = Observable(Point3f0(torso_top[][1] + shoulder_offset, 
                                     torso_top[][2], 
                                     torso_top[][3]))

#Lokcie sa punktem laczenia ramion i przedramion
left_elbow = Observable(Point3f0(left_arm_pos[][2][1], 
                                 left_arm_pos[][2][2], 
                                 left_arm_pos[][2][3]))
right_elbow = Observable(Point3f0(right_arm_pos[][2][1], 
                                  right_arm_pos[][2][2], 
                                  right_arm_pos[][2][3]))

#Nadgarstki to konce przedramion
left_wrist = Observable(Point3f0(left_forearm_pos[][2][1], 
                                 left_forearm_pos[][2][2], 
                                 left_forearm_pos[][2][3]))
right_wrist = Observable(Point3f0(right_forearm_pos[][2][1], 
                                  right_forearm_pos[][2][2], 
                                  right_forearm_pos[][2][3]))

#Biodra sa punktem laczenia ud i tulowia
hips = Observable(Point3f0(left_thigh_pos[][1][1], 
                               left_thigh_pos[][1][2], 
                               left_thigh_pos[][1][3]))

#Kolana sa punktem laczacym piszczele i uda
left_knee = Observable(Point3f0(left_shin_pos[][1][1], 
                                left_shin_pos[][1][2], 
                                left_shin_pos[][1][3]))
right_knee = Observable(Point3f0(right_shin_pos[][1][1], 
                                 right_shin_pos[][1][2], 
                                 right_shin_pos[][1][3]))

#Jako kostki przyjmujemy pozycje stop
left_ankle = Observable(Point3f0(left_foot[1], left_foot[2], left_foot[3]))
right_ankle = Observable(Point3f0(right_foot[1], right_foot[2], right_foot[3]))



# Lista kluczowych punktów z ich nazwami i obserwowalnymi zmiennymi
keypoint_names = [
    "Nose", "Left Eye", "Right Eye", "Left Ear", "Right Ear",
    "Left Shoulder", "Right Shoulder", "Left Elbow", "Right Elbow",
    "Left Wrist", "Right Wrist", "Hips",
    "Left Knee", "Right Knee", "Left Ankle", "Right Ankle"
]

keypoints = [
    nose, left_eye, right_eye, left_ear, right_ear,
    left_shoulder, right_shoulder, left_elbow, right_elbow,
    left_wrist, right_wrist, hips,
    left_knee, right_knee, left_ankle, right_ankle
]

#Wyswietlanie Keypointow
keypoints_label = Label(
    fig[1, 10], 
    text = "Key Points Coordinates:", 
    fontsize = 12, 
    halign = :right, 
    valign = :top
)

function update_keypoints()
    # Aktualizacja punktów kluczowych na podstawie modelu czlowieka
    #Np. pozycja oczu uszu i nos sa kalkulowane na podstawie glowy head_pos
    nose[] = head_pos[][1] + nose_offset
    left_eye[] = head_pos[][1] + Point3f0(-eye_offset_x, 0, eye_offset_z)
    right_eye[] = head_pos[][1] + Point3f0(eye_offset_x, 0, eye_offset_z)
    left_ear[] = head_pos[][1] + Point3f0(-ear_offset_x, 0, ear_offset_z)
    right_ear[] = head_pos[][1] + Point3f0(ear_offset_x, 0, ear_offset_z)

    #Barki sa symetrycznie oddalone od gory tulowia wzgledem osi X
    left_shoulder[] = torso_top[] + Point3f0(-shoulder_offset, 0, 0)
    right_shoulder[] = torso_top[] + Point3f0(shoulder_offset, 0, 0) 

    
    left_elbow[] = left_arm_pos[][2]
    right_elbow[] = right_arm_pos[][2]

    
    left_wrist[] = left_forearm_pos[][2] + Point3f0(0, -forearm_length, 0)
    right_wrist[] = right_forearm_pos[][2] + Point3f0(0, -forearm_length, 0)

    
    hips[] = left_thigh_pos[][1]
    
    
    left_knee[] = left_shin_pos[][1]
    right_knee[] = right_shin_pos[][1]

   
    left_ankle[] = left_foot
    right_ankle[] = right_foot
end

#Parametry wyswietlane w lewej czesci ekranu, mase czlowieka mozna zmienic wczesniej w kodzie
repetition_count_label = Label(fig[8, 1], text = "Repetitions: 0", fontsize = 14, halign = :left, valign = :top)
human_mass = Label(fig[9, 1], text = "Mass of Human: $mass_human kg", fontsize = 14, halign = :left, valign = :top)
weight_label = Label(fig[10, 1], text = "Mass of Weights: 0.0 kg each", fontsize = 14, halign = :left, valign = :top)
generated_power_label = Label(fig[11, 1], text = "Generated Power: 0.0 W", fontsize = 14, halign = :left, valign = :top)
potential_energy_label = Label(fig[12, 1], text = "Potential Energy: 0.0 J", fontsize = 14, halign = :left, valign = :top)
kinetic_energy_label = Label(fig[13, 1], text = "Kinetic Energy: 0.0 J", fontsize = 14, halign = :left, valign = :top)
work_done_label = Label(fig[14, 1], text = "Work Done: 0.0 J", fontsize = 14, halign = :left, valign = :top)
velocity_label = Label(fig[15, 1], text = "Velocity: 0.0 m/s", fontsize = 14, halign = :left, valign = :top)




#Wyswietlenie calej sceny przed rozpoczeciem animacji
display(fig)

#Generowanie talerzy od samego poczatku, potrzebne zeby animacja byla plynna
left_weight_pos[] = left_weight_pos[]
right_weight_pos[] = right_weight_pos[]

@async begin
    global previous_velocity
    global previous_hip_y
    global rep_count
    try
        direction = 1
        progress = 0.0
        previous_hip_y = hip[][2]
        while true
            if !is_running[]
                # Wstrzymaj animację
                sleep(0.1)
                continue
            end

            progress += direction * (1 / time_steps)
            if progress >= 1.0
                progress = 1.0
                direction = -1
            elseif progress <= 0.0
                progress = 0.0
                direction = 1
                rep_count[] += 1
            end
        
            # Aktualizacja pozycji biodra
            new_hip_height = hip_height - 0.6 * progress
            new_hip_z = -0.1 * progress
            hip[] = Point3f0(0, new_hip_height, new_hip_z)
           
            # Aktualizacja pozycji tulowia
            tilt_angle = (π / 8) * progress
            torso_base = hip[]
            new_torso_top = torso_base + Point3f0(0, segment_length * cos(tilt_angle), segment_length * sin(tilt_angle))
            torso_pos[] = [torso_base, new_torso_top]
            torso_top[] = new_torso_top

            # Aktualizacja pozycji ramion
            left_shoulder[] = torso_top[] + Point3f0(-shoulder_offset, 0, 0)
            right_shoulder[] = torso_top[] + Point3f0(shoulder_offset, 0, 0)
            bridge_pos[] = [left_shoulder[], right_shoulder[]]

            # Aktualizacja pozycji ud
            left_knee = Point3f0(left_foot[1], (hip_height + new_hip_height - 0.5) / 3, 0.1 * progress + 0.2)
            right_knee = Point3f0(right_foot[1], (hip_height + new_hip_height - 0.5) / 3, 0.1 * progress + 0.2)
            left_thigh_pos[] = [hip[], left_knee]
            right_thigh_pos[] = [hip[], right_knee]

            # Aktualizacja pozycji goleni
            left_shin_pos[] = [left_knee, left_foot]
            right_shin_pos[] = [right_knee, right_foot]

            # Aktualizacja pozycji ramion
            left_arm_start = left_shoulder[]
            right_arm_start = right_shoulder[]
            left_arm_end = left_arm_start + Point3f0(-arm_length * cos(π / 4), -arm_length * sin(π / 4), 0)
            right_arm_end = right_arm_start + Point3f0(arm_length * cos(π / 4), -arm_length * sin(π / 4), 0)
            left_arm_pos[] = [left_arm_start, left_arm_end]
            right_arm_pos[] = [right_arm_start, right_arm_end]

            # Aktualizacja pozycji przedramion
            left_forearm_pos[] = [left_arm_end, left_arm_end - Point3f0(0, forearm_length, 0)]
            right_forearm_pos[] = [right_arm_end, right_arm_end - Point3f0(0, forearm_length, 0)]

            # Aktualizacja pozycji glowy
            head_pos[] = [torso_top[] + Point3f0(0, head_radius, 0)]

            # Aktualna wspolrzedna y biodra i sztangi
            current_hip_y = hip[][2]
            current_barbell_y = torso_top[][2]

            # Obliczanie predkosci na postawie zmiany polozenia
            current_velocity = (current_hip_y - previous_hip_y) / delta_t
            velocity[] = current_velocity
        
            # Obliczanie Energii Kinetycznej:  0.5 * m * v^2
            current_kinetic_energy = 0.5 * mass_total[] * (current_velocity)^2
            kinetic_energy[] = current_kinetic_energy
            # Obliczanie Energii Potencjalnej:  m * g * h
            potential_energy_val = mass_total[] * g * current_barbell_y

            # Siła miesni rownowazy sile grawitacji: F = m * g
            force = mass_total[] * g

            #Miesnie generuja moc tylko podczas ruchu w gore
            if current_velocity > 0
                #Ruch w gore
                current_power = force * current_velocity
                generated_power[] = current_power       
                work_done[] += force * (current_hip_y - previous_hip_y)
            else
                #Ruch w dol
                current_power = 0.0
                generated_power[] = current_power           
            end
           
           
            #Wyswietlanie i aktualizowanie wczesniej policzonych parametrow
            weight_label.text = "Mass of Weights: $(round(mass_weight[], digits=2)) kg each"                      
            potential_energy_label.text = "Potential Energy of the barbell: $(round(potential_energy_val, digits=2)) J"
            velocity_label.text = "Velocity: $(round(current_velocity, digits=2)) m/s"
            kinetic_energy_label.text = "Kinetic Energy of the barbell: $(round(current_kinetic_energy, digits=2)) J"
            generated_power_label.text = "Generated muscle power: $(round(current_power, digits=2)) W"
            work_done_label.text = "Work Done: $(round(work_done[], digits=2)) J"
            repetition_count_label.text = "Repetitions: $(rep_count[])"
            
      #Keypointy 
      update_keypoints()
      coord_text = "Key Points Coordinates:\n"
      for (i, (name, kp)) in enumerate(zip(keypoint_names, keypoints))
          x, y, z = kp[][1], kp[][2], kp[][3]
          coord_text *= "$i: $name (X: $(round(x, digits=2)), Y: $(round(y, digits=2)), Z: $(round(z, digits=2)))\n"
      end
      keypoints_label.text = coord_text

           #Aktualizacja predkosci potrzebna do dynamicznych obliczen
            previous_hip_y = current_hip_y
            previous_velocity = current_velocity

            # Aktualizacja obciazenia jezeli przycisk jest wcisniety, pomagal przy modelowaniu ruchu
            if barbell_visible[]                
                barbell_central[] = [
                    left_shoulder[] + Point3f0(-barbell_length / 2, 0, 0),
                    right_shoulder[] + Point3f0(barbell_length / 2, 0, 0)
                ]               
                left_weight_pos[] = left_shoulder[] + Point3f0(-barbell_length / 2, 0, 0) + Point3f0(-weight_length / 2, 0, 0)
                right_weight_pos[] = right_shoulder[] + Point3f0(barbell_length / 2, 0, 0) + Point3f0(weight_length / 2, 0, 0)
            end

            sleep(0.05)  # Sprawia ze animacja jest plynniejsza
        end
    catch e
        println("An error occurred: ", e)
    end
end

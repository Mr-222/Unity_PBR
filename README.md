[![license](https://img.shields.io/badge/license-Unlicense-blue)](LICENSE)
# PBR for Unity's Universal Render Pipeline

## This project implements:
-  **Standard material (with clear coat and energy compensation)**             
-  **Anisotropy material**         
-  **Cloth material**             
-  **Temporal antialiasing (TAA)**    
-  **Area light using Linearly Transformed Cosines**      
-  **Parallax Occlusion Mapping**      
-  **Tessellation (with Displacement Map)**

## Results
**Standard, Clear coat, Anisotropy, Cloth materials**
![Mats](Pics/material%20model.png)

**Area light**
![LTC1](Pics/LTC.png)

![LTC2](Pics/LTC%202.jpg)

**TAA**
![TAA](Pics/TAA.jpeg)

**Tessellation**
![Tessellation](Pics/tessellation.jpeg)

## Requirements
- Unity 2021.3 LTS or higher.

## Instruction
- To use materials, just create new material with corresponding shader(Lit/Anisotropy/Cloth).
- To enable clear coat or energy compensation, enable corresponding checkbox.
![Instruction_mat](Pics/Instruct_mat.png)
- To enable TAA, enable the RendererFeature "TAA".
![Instruction_TAA](Pics/Instruct_TAA.png)
- To use area light, add a "Quad Area Light" script to a quad.
![Instruction_AreaLight](Pics/Instruct_LTC.png)
- To enable tessellation, modify following item in material property.
- ![Instruction_Tessellation](Pics/Instruct_Tessellation.png)

## Known Issue
If you can't load the Unity project properly, try **[Assets/Reimport All]**.
![Issue](Pics/Reimport.png)

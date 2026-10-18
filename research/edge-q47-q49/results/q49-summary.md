| Phase | Region (colo) | Worker | Route | n | Client ms: median (min-max) | D1 ms in Worker | Placement | D1 served by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| base | wnam (DFW) | default | closure | 6 | 161 (159-164) | 153 (149-153) |  | EEUR primary |
| base | wnam (DFW) | default | chain3 | 6 | 464 (460-466) | 450 (448-450) |  | EEUR primary |
| base | wnam (DFW) | default | publish | 6 | 332 (330-338) | 321 (320-323) |  | EEUR primary |
| base | wnam (DFW) | smart | closure | 6 | 165 (159-168) | 153 (149-157) | local-DFW | EEUR primary |
| base | wnam (DFW) | smart | chain3 | 6 | 466 (463-471) | 452 (449-456) | local-DFW | EEUR primary |
| base | wnam (DFW) | smart | publish | 6 | 335 (332-337) | 323 (321-325) | local-DFW | EEUR primary |
| base | weur (LHR) | default | closure | 6 | 37 (36-41) | 29 (28-34) |  | EEUR primary |
| base | weur (LHR) | default | chain3 | 6 | 101 (97-103) | 89 (86-90) |  | EEUR primary |
| base | weur (LHR) | default | publish | 6 | 94 (89-98) | 84 (80-89) |  | EEUR primary |
| base | weur (LHR) | smart | closure | 6 | 41 (39-44) | 31 (28-36) | local-LHR | EEUR primary |
| base | weur (LHR) | smart | chain3 | 6 | 109 (105-122) | 96 (90-108) | local-LHR | EEUR primary |
| base | weur (LHR) | smart | publish | 6 | 98 (92-103) | 87 (82-92) | local-LHR | EEUR primary |
| base | apac (KIX) | default | closure | 6 | 248 (244-254) | 243 (239-250) |  | EEUR primary |
| base | apac (KIX) | default | chain3 | 6 | 744 (735-755) | 736 (727-747) |  | EEUR primary |
| base | apac (KIX) | default | publish | 6 | 518 (508-521) | 512 (500-515) |  | EEUR primary |
| base | apac (KIX) | smart | closure | 6 | 253 (250-262) | 246 (242-255) | local-KIX | EEUR primary |
| base | apac (KIX) | smart | chain3 | 6 | 736 (732-749) | 727 (722-738) | local-KIX | EEUR primary |
| base | apac (KIX) | smart | publish | 6 | 523 (511-526) | 515 (503-518) | local-KIX | EEUR primary |
| base | local (TBS (this machine)) | default | closure | 6 | 90 (85-98) | 71 (69-78) |  | EEUR primary |
| base | local (TBS (this machine)) | default | chain3 | 6 | 228 (223-240) | 207 (201-217) |  | EEUR primary |
| base | local (TBS (this machine)) | default | publish | 6 | 187 (174-224) | 165 (155-205) |  | EEUR primary |
| base | local (TBS (this machine)) | smart | closure | 6 | 94 (86-104) | 68 (67-72) | local-TBS | EEUR primary |
| base | local (TBS (this machine)) | smart | chain3 | 6 | 241 (227-307) | 211 (205-218) | local-TBS | EEUR primary |
| base | local (TBS (this machine)) | smart | publish | 6 | 197 (186-298) | 168 (160-278) | local-TBS | EEUR primary |
| repl1 | wnam (DFW) | default | closure | 4 | 162 (161-165) | 153 (152-156) |  | EEUR primary |
| repl1 | wnam (DFW) | default | closure_s | 4 | 22 (21-22) | 13 (12-14) |  | WNAM replica |
| repl1 | wnam (DFW) | default | chain3 | 4 | 468 (466-469) | 453 (450-453) |  | EEUR primary |
| repl1 | wnam (DFW) | default | chain3_s | 4 | 49 (44-53) | 36 (32-39) |  | WNAM replica |
| repl1 | wnam (DFW) | smart | closure | 4 | 163 (160-165) | 151 (150-153) | local-DFW | EEUR primary |
| repl1 | wnam (DFW) | smart | closure_s | 4 | 24 (23-27) | 14 (12-17) | local-DFW | WNAM replica |
| repl1 | wnam (DFW) | smart | chain3 | 4 | 465 (460-467) | 449 (445-450) | local-DFW | EEUR primary |
| repl1 | wnam (DFW) | smart | chain3_s | 4 | 51 (48-54) | 36 (33-39) | local-DFW | WNAM replica |
| repl1 | weur (LHR) | default | closure | 4 | 39 (37-45) | 32 (31-34) |  | EEUR primary |
| repl1 | weur (LHR) | default | closure_s | 4 | 38 (36-39) | 30 (29-31) |  | EEUR primary |
| repl1 | weur (LHR) | default | chain3 | 4 | 102 (100-104) | 90 (89-93) |  | EEUR primary |
| repl1 | weur (LHR) | default | chain3_s | 4 | 100 (99-103) | 90 (88-93) |  | EEUR primary |
| repl1 | weur (LHR) | smart | closure | 4 | 43 (37-48) | 33 (28-38) | local-LHR | EEUR primary |
| repl1 | weur (LHR) | smart | closure_s | 4 | 38 (37-42) | 30 (29-34) | local-LHR | EEUR primary |
| repl1 | weur (LHR) | smart | chain3 | 4 | 106 (97-107) | 93 (86-96) | local-LHR | EEUR primary |
| repl1 | weur (LHR) | smart | chain3_s | 4 | 107 (100-112) | 94 (87-96) | local-LHR | EEUR primary |
| repl1 | apac (KIX) | default | closure | 4 | 251 (249-261) | 245 (244-255) |  | EEUR primary |
| repl1 | apac (KIX) | default | closure_s | 4 | 55 (52-56) | 49 (47-51) |  | APAC replica |
| repl1 | apac (KIX) | default | chain3 | 4 | 742 (739-748) | 735 (731-741) |  | EEUR primary |
| repl1 | apac (KIX) | default | chain3_s | 4 | 158 (154-164) | 149 (146-156) |  | APAC replica |
| repl1 | apac (KIX) | smart | closure | 4 | 252 (249-253) | 245 (243-247) | local-KIX | EEUR primary |
| repl1 | apac (KIX) | smart | closure_s | 4 | 58 (55-59) | 51 (48-52) | local-KIX | APAC replica |
| repl1 | apac (KIX) | smart | chain3 | 4 | 744 (729-745) | 734 (719-735) | local-KIX | EEUR primary |
| repl1 | apac (KIX) | smart | chain3_s | 4 | 162 (155-163) | 151 (142-152) | local-KIX | APAC replica |
| repl1 | local (TBS (this machine)) | default | closure | 4 | 85 (83-90) | 66 (66-73) |  | EEUR primary |
| repl1 | local (TBS (this machine)) | default | closure_s | 4 | 87 (85-92) | 68 (68-72) |  | EEUR primary |
| repl1 | local (TBS (this machine)) | default | chain3 | 4 | 224 (222-236) | 204 (201-212) |  | EEUR primary |
| repl1 | local (TBS (this machine)) | default | chain3_s | 4 | 228 (220-231) | 207 (200-210) |  | EEUR primary |
| repl1 | local (TBS (this machine)) | smart | closure | 4 | 92 (87-93) | 72 (68-73) | local-TBS | EEUR primary |
| repl1 | local (TBS (this machine)) | smart | closure_s | 4 | 88 (87-94) | 69 (68-73) | local-TBS | EEUR primary |
| repl1 | local (TBS (this machine)) | smart | chain3 | 4 | 230 (225-284) | 210 (204-263) | local-TBS | EEUR primary |
| repl1 | local (TBS (this machine)) | smart | chain3_s | 4 | 235 (230-238) | 214 (211-215) | local-TBS | EEUR primary |
| p1 | wnam (DFW) | default | closure | 4 | 161 (160-163) | 153 (151-154) |  | EEUR primary |
| p1 | wnam (DFW) | default | chain3 | 4 | 463 (461-464) | 450 (449-452) |  | EEUR primary |
| p1 | wnam (DFW) | default | publish | 4 | 334 (331-339) | 324 (321-327) |  | EEUR primary |
| p1 | wnam (DFW) | smart | closure | 4 | 163 (162-165) | 152 (151-153) | local-DFW | EEUR primary |
| p1 | wnam (DFW) | smart | chain3 | 4 | 462 (460-465) | 448 (447-449) | local-DFW | EEUR primary |
| p1 | wnam (DFW) | smart | publish | 4 | 333 (330-337) | 320 (320-322) | local-DFW | EEUR primary |
| p1 | wnam (DFW) | hint | closure | 4 | 184 (177-200) | 25 (23-27) | remote-FRA | EEUR primary |
| p1 | wnam (DFW) | hint | chain3 | 4 | 236 (226-269) | 72 (68-75) | remote-FRA | EEUR primary |
| p1 | wnam (DFW) | hint | publish | 4 | 229 (219-246) | 69 (62-70) | remote-FRA | EEUR primary |
| p1 | weur (LHR) | default | closure | 4 | 40 (36-42) | 31 (30-35) |  | EEUR primary |
| p1 | weur (LHR) | default | chain3 | 4 | 106 (101-119) | 95 (91-105) |  | EEUR primary |
| p1 | weur (LHR) | default | publish | 4 | 101 (88-186) | 91 (79-176) |  | EEUR primary |
| p1 | weur (LHR) | smart | closure | 4 | 39 (38-41) | 30 (28-30) | local-LHR | EEUR primary |
| p1 | weur (LHR) | smart | chain3 | 4 | 106 (99-108) | 91 (86-93) | local-LHR | EEUR primary |
| p1 | weur (LHR) | smart | publish | 4 | 95 (91-96) | 83 (81-85) | local-LHR | EEUR primary |
| p1 | weur (LHR) | hint | closure | 4 | 58 (51-92) | 24 (24-26) | remote-FRA | EEUR primary |
| p1 | weur (LHR) | hint | chain3 | 4 | 115 (91-120) | 73 (63-76) | remote-FRA | EEUR primary |
| p1 | weur (LHR) | hint | publish | 4 | 106 (93-136) | 67 (63-75) | remote-FRA | EEUR primary |
| p1 | apac (KIX) | default | closure | 4 | 250 (244-258) | 245 (239-253) |  | EEUR primary |
| p1 | apac (KIX) | default | chain3 | 4 | 745 (739-751) | 737 (732-744) |  | EEUR primary |
| p1 | apac (KIX) | default | publish | 4 | 514 (508-521) | 507 (502-515) |  | EEUR primary |
| p1 | apac (KIX) | smart | closure | 4 | 251 (248-253) | 244 (241-244) | local-KIX | EEUR primary |
| p1 | apac (KIX) | smart | chain3 | 4 | 743 (737-770) | 733 (724-759) | local-KIX | EEUR primary |
| p1 | apac (KIX) | smart | publish | 4 | 518 (512-594) | 508 (504-585) | local-KIX | EEUR primary |
| p1 | apac (KIX) | hint | closure | 4 | 278 (265-307) | 25 (23-30) | remote-FRA | EEUR primary |
| p1 | apac (KIX) | hint | chain3 | 4 | 347 (326-356) | 78 (76-82) | remote-FRA | EEUR primary |
| p1 | apac (KIX) | hint | publish | 4 | 322 (311-339) | 69 (65-72) | remote-FRA | EEUR primary |
| p1 | local (TBS (this machine)) | default | closure | 4 | 91 (84-95) | 69 (67-74) |  | EEUR primary |
| p1 | local (TBS (this machine)) | default | chain3 | 4 | 236 (227-351) | 214 (203-217) |  | EEUR primary |
| p1 | local (TBS (this machine)) | default | publish | 4 | 184 (183-236) | 165 (162-168) |  | EEUR primary |
| p1 | local (TBS (this machine)) | smart | closure | 4 | 87 (83-94) | 68 (66-73) | local-TBS | EEUR primary |
| p1 | local (TBS (this machine)) | smart | chain3 | 4 | 230 (227-239) | 209 (206-214) | local-TBS | EEUR primary |
| p1 | local (TBS (this machine)) | smart | publish | 4 | 183 (181-184) | 162 (159-164) | local-TBS | EEUR primary |
| p1 | local (TBS (this machine)) | hint | closure | 4 | 117 (112-139) | 24 (20-27) | remote-FRA | EEUR primary |
| p1 | local (TBS (this machine)) | hint | chain3 | 4 | 176 (171-179) | 74 (72-78) | remote-FRA | EEUR primary |
| p1 | local (TBS (this machine)) | hint | publish | 4 | 165 (156-179) | 68 (66-71) | remote-FRA | EEUR primary |
| p2 | wnam (DFW) | default | closure_s | 4 | 23 (21-25) | 15 (11-16) |  | WNAM replica |
| p2 | wnam (DFW) | default | chain3_s | 4 | 47 (45-54) | 33 (32-42) |  | WNAM replica |
| p2 | wnam (DFW) | hint | closure_s | 4 | 186 (178-193) | 23 (21-28) | remote-FRA | EEUR primary |
| p2 | wnam (DFW) | hint | chain3_s | 4 | 243 (238-267) | 74 (72-75) | remote-FRA | EEUR primary |
| p2 | weur (LHR) | default | closure_s | 4 | 40 (37-43) | 33 (30-36) |  | EEUR primary |
| p2 | weur (LHR) | default | chain3_s | 4 | 105 (105-110) | 94 (94-100) |  | EEUR primary |
| p2 | weur (LHR) | hint | closure_s | 4 | 68 (57-86) | 24 (23-27) | remote-FRA | EEUR primary |
| p2 | weur (LHR) | hint | chain3_s | 4 | 127 (115-138) | 79 (69-92) | remote-FRA | EEUR primary |
| p2 | apac (KIX) | default | closure_s | 4 | 53 (52-276) | 48 (47-271) |  | EEUR primary, APAC replica |
| p2 | apac (KIX) | default | chain3_s | 4 | 155 (147-166) | 147 (139-155) |  | APAC replica |
| p2 | apac (KIX) | hint | closure_s | 4 | 275 (266-283) | 24 (21-29) | remote-FRA | EEUR primary |
| p2 | apac (KIX) | hint | chain3_s | 4 | 334 (329-338) | 75 (70-90) | remote-FRA | EEUR primary |
| p2 | local (TBS (this machine)) | default | closure_s | 4 | 88 (85-94) | 71 (66-73) |  | EEUR primary |
| p2 | local (TBS (this machine)) | default | chain3_s | 4 | 227 (222-233) | 204 (199-210) |  | EEUR primary |
| p2 | local (TBS (this machine)) | hint | closure_s | 4 | 125 (111-133) | 25 (22-27) | remote-FRA | EEUR primary |
| p2 | local (TBS (this machine)) | hint | chain3_s | 4 | 182 (161-190) | 73 (69-81) | remote-FRA | EEUR primary |
| p3 | wnam (DFW) | default | closure | 4 | 160 (160-162) | 152 (151-153) |  | EEUR primary |
| p3 | wnam (DFW) | default | chain3 | 4 | 465 (461-470) | 452 (450-456) |  | EEUR primary |
| p3 | wnam (DFW) | default | publish | 4 | 336 (333-367) | 325 (322-354) |  | EEUR primary |
| p3 | wnam (DFW) | smart | closure | 4 | 163 (160-164) | 152 (151-153) | local-DFW | EEUR primary |
| p3 | wnam (DFW) | smart | chain3 | 4 | 466 (465-470) | 452 (450-453) | local-DFW | EEUR primary |
| p3 | wnam (DFW) | smart | publish | 4 | 335 (333-336) | 322 (321-323) | local-DFW | EEUR primary |
| p3 | wnam (DFW) | hint | closure | 4 | 187 (176-234) | 26 (21-29) | remote-FRA | EEUR primary |
| p3 | wnam (DFW) | hint | chain3 | 4 | 251 (238-315) | 80 (65-143) | remote-FRA | EEUR primary |
| p3 | wnam (DFW) | hint | publish | 4 | 239 (223-260) | 73 (69-77) | remote-FRA | EEUR primary |
| p3 | weur (LHR) | default | closure | 4 | 43 (37-56) | 32 (30-40) |  | EEUR primary |
| p3 | weur (LHR) | default | chain3 | 4 | 111 (105-128) | 96 (92-106) |  | EEUR primary |
| p3 | weur (LHR) | default | publish | 4 | 96 (93-111) | 85 (84-95) |  | EEUR primary |
| p3 | weur (LHR) | smart | closure | 4 | 44 (43-45) | 35 (35-35) | local-LHR | EEUR primary |
| p3 | weur (LHR) | smart | chain3 | 4 | 118 (114-121) | 106 (100-107) | local-LHR | EEUR primary |
| p3 | weur (LHR) | smart | publish | 4 | 100 (97-106) | 91 (88-95) | local-LHR | EEUR primary |
| p3 | weur (LHR) | hint | closure | 4 | 59 (56-75) | 23 (20-26) | remote-FRA | EEUR primary |
| p3 | weur (LHR) | hint | chain3 | 4 | 106 (95-110) | 65 (59-70) | remote-FRA | EEUR primary |
| p3 | weur (LHR) | hint | publish | 4 | 104 (100-281) | 68 (67-245) | remote-FRA | EEUR primary |
| p3 | apac (KIX) | default | closure | 4 | 251 (248-253) | 246 (243-247) |  | EEUR primary |
| p3 | apac (KIX) | default | chain3 | 4 | 739 (730-739) | 731 (722-732) |  | EEUR primary |
| p3 | apac (KIX) | default | publish | 4 | 509 (507-541) | 503 (500-535) |  | EEUR primary |
| p3 | apac (KIX) | smart | closure | 4 | 254 (249-263) | 245 (243-256) | local-KIX | EEUR primary |
| p3 | apac (KIX) | smart | chain3 | 4 | 735 (732-743) | 726 (722-734) | local-KIX | EEUR primary |
| p3 | apac (KIX) | smart | publish | 4 | 518 (512-524) | 510 (502-515) | local-KIX | EEUR primary |
| p3 | apac (KIX) | hint | closure | 4 | 269 (260-273) | 25 (21-28) | remote-FRA | EEUR primary |
| p3 | apac (KIX) | hint | chain3 | 4 | 318 (307-341) | 68 (63-85) | remote-FRA | EEUR primary |
| p3 | apac (KIX) | hint | publish | 4 | 318 (308-330) | 66 (64-69) | remote-FRA | EEUR primary |
| p3 | local (TBS (this machine)) | default | closure | 4 | 88 (83-92) | 68 (65-74) |  | EEUR primary |
| p3 | local (TBS (this machine)) | default | chain3 | 4 | 231 (226-240) | 208 (201-214) |  | EEUR primary |
| p3 | local (TBS (this machine)) | default | publish | 4 | 182 (175-187) | 163 (155-167) |  | EEUR primary |
| p3 | local (TBS (this machine)) | smart | closure | 4 | 88 (84-89) | 68 (67-70) | local-TBS | EEUR primary |
| p3 | local (TBS (this machine)) | smart | chain3 | 4 | 232 (230-244) | 209 (205-213) | local-TBS | EEUR primary |
| p3 | local (TBS (this machine)) | smart | publish | 4 | 182 (178-192) | 163 (158-167) | local-TBS | EEUR primary |
| p3 | local (TBS (this machine)) | hint | closure | 4 | 117 (108-125) | 23 (21-26) | remote-FRA | EEUR primary |
| p3 | local (TBS (this machine)) | hint | chain3 | 4 | 170 (161-215) | 68 (64-72) | remote-FRA | EEUR primary |
| p3 | local (TBS (this machine)) | hint | publish | 4 | 160 (153-175) | 69 (63-78) | remote-FRA | EEUR primary |

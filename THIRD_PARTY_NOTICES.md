# Third-Party Notices

Irodence uses data from the following open-source projects.

---

## react-native-body-highlighter

- **Source:** https://github.com/HichamELBSI/react-native-body-highlighter
- **Used for:** muscle geometry (SVG path data for front/back, male/female
  body diagrams) in `Irodence/Core/Muscles/MuscleGeometryData.swift` and the
  body outline artwork. The geometry was converted to native SwiftUI paths;
  no runtime code from the project is included.
- **License:** MIT

```
MIT License

Copyright (c) 2022 ELABBASSI Hicham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## free-exercise-db (schema reference)

- **Source:** https://github.com/yuhonas/free-exercise-db
- **Used for:** muscle-name conventions (`primaryMuscles`/`secondaryMuscles`
  strings) that `Muscle.fromExercise(primary:secondary:)` maps onto diagram
  muscles.
- **License:** Public domain / Unlicense

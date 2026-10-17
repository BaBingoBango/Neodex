import Accelerate
import Foundation

/// Multinomial logistic regression on standardised feature vectors, trained with Adam and an L2
/// penalty. Small enough to run in seconds per epoch with BLAS, and exactly what the app evaluates:
/// `softmax(Wᵀ · (x − mean) / std + b)`.
struct SoftmaxTrainer {
    struct Sample {
        var features: [Float]
        var label: Int
    }

    struct Model {
        var dimension: Int
        var classCount: Int
        var mean: [Float]
        var std: [Float]
        /// Row-major `dimension × classCount`.
        var weights: [Float]
        var biases: [Float]

        /// Class probabilities for one raw feature vector.
        func probabilities(for features: [Float]) -> [Float] {
            var x = [Float](repeating: 0, count: dimension)
            for d in 0..<dimension { x[d] = (features[d] - mean[d]) / std[d] }
            var logits = biases
            cblas_sgemv(CblasRowMajor, CblasTrans, Int32(dimension), Int32(classCount), 1, weights, Int32(classCount), x, 1, 1, &logits, 1)
            return SoftmaxTrainer.softmax(logits)
        }
    }

    struct Outcome {
        var trainingAccuracy: Double
        var validationAccuracy: Double?
        var confusions: [(label: Int, predicted: Int, count: Int)]
        var epochs: Int
    }

    var epochs = 40
    var batchSize = 256
    var learningRate: Float = 0.002
    var weightDecay: Float = 1e-4

    func train(_ training: [Sample], validation: [Sample], classCount: Int, log: Pipeline.Log) -> (Model, Outcome) {
        let dimension = training.first?.features.count ?? FeatureExtractor.dimension
        let n = training.count

        // Standardise with the training set's statistics.
        var mean = [Float](repeating: 0, count: dimension)
        var std = [Float](repeating: 0, count: dimension)
        for sample in training { vDSP.add(mean, sample.features, result: &mean) }
        vDSP.divide(mean, Float(n), result: &mean)
        for sample in training {
            var centered = [Float](repeating: 0, count: dimension)
            vDSP.subtract(sample.features, mean, result: &centered)
            vDSP.multiply(centered, centered, result: &centered)
            vDSP.add(std, centered, result: &std)
        }
        vDSP.divide(std, Float(n), result: &std)
        std = std.map { max(sqrt($0), 1e-3) }

        func standardised(_ samples: [Sample]) -> [Float] {
            var matrix = [Float](repeating: 0, count: samples.count * dimension)
            for (row, sample) in samples.enumerated() {
                for d in 0..<dimension { matrix[row * dimension + d] = (sample.features[d] - mean[d]) / std[d] }
            }
            return matrix
        }
        let x = standardised(training)
        let labels = training.map(\.label)
        let xValidation = standardised(validation)
        let validationLabels = validation.map(\.label)

        var weights = [Float](repeating: 0, count: dimension * classCount)
        var biases = [Float](repeating: 0, count: classCount)
        var m = [Float](repeating: 0, count: weights.count), v = m
        var mb = [Float](repeating: 0, count: classCount), vb = mb
        var step: Float = 0
        var best = (accuracy: -1.0, weights: weights, biases: biases, epoch: 0)
        var generator = SeededGenerator(seed: 2026)
        var order = Array(0..<n)

        for epoch in 1...epochs {
            order.shuffle(using: &generator)
            let decayed = learningRate * Float(0.5 * (1 + cos(Double(epoch - 1) / Double(epochs) * .pi)))
            for start in stride(from: 0, to: n, by: batchSize) {
                let rows = Array(order[start..<min(start + batchSize, n)])
                let b = rows.count
                var xb = [Float](repeating: 0, count: b * dimension)
                for (i, row) in rows.enumerated() {
                    xb.replaceSubrange(i * dimension..<(i + 1) * dimension, with: x[row * dimension..<(row + 1) * dimension])
                }
                // logits = xb · W + biases
                var logits = [Float](repeating: 0, count: b * classCount)
                for i in 0..<b { logits.replaceSubrange(i * classCount..<(i + 1) * classCount, with: biases) }
                cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(b), Int32(classCount), Int32(dimension),
                            1, xb, Int32(dimension), weights, Int32(classCount), 1, &logits, Int32(classCount))
                // dLogits = (softmax − onehot) / b
                var dLogits = logits
                for i in 0..<b {
                    let slice = Self.softmax(Array(logits[i * classCount..<(i + 1) * classCount]))
                    dLogits.replaceSubrange(i * classCount..<(i + 1) * classCount, with: slice)
                    dLogits[i * classCount + labels[rows[i]]] -= 1
                }
                vDSP.divide(dLogits, Float(b), result: &dLogits)
                // gradW = xbᵀ · dLogits + decay · W ; gradB = column sums
                var gradW = weights
                vDSP.multiply(weightDecay, weights, result: &gradW)
                cblas_sgemm(CblasRowMajor, CblasTrans, CblasNoTrans, Int32(dimension), Int32(classCount), Int32(b),
                            1, xb, Int32(dimension), dLogits, Int32(classCount), 1, &gradW, Int32(classCount))
                var gradB = [Float](repeating: 0, count: classCount)
                for i in 0..<b { vDSP.add(gradB, Array(dLogits[i * classCount..<(i + 1) * classCount]), result: &gradB) }

                step += 1
                Self.adam(&weights, gradient: gradW, m: &m, v: &v, step: step, learningRate: decayed)
                Self.adam(&biases, gradient: gradB, m: &mb, v: &vb, step: step, learningRate: decayed)
            }

            if epoch % 5 == 0 || epoch == epochs {
                let trainingAccuracy = Self.accuracy(x: x, labels: labels, weights: weights, biases: biases, dimension: dimension, classCount: classCount, limit: 8000)
                var line = "  epoch \(epoch): training \(ClassifierTrainer.percent(trainingAccuracy))"
                if !validation.isEmpty {
                    let validationAccuracy = Self.accuracy(x: xValidation, labels: validationLabels, weights: weights, biases: biases, dimension: dimension, classCount: classCount, limit: nil)
                    line += ", validation \(ClassifierTrainer.percent(validationAccuracy))"
                    if validationAccuracy > best.accuracy { best = (validationAccuracy, weights, biases, epoch) }
                } else {
                    best = (trainingAccuracy, weights, biases, epoch)
                }
                log(line)
            }
        }

        let model = Model(dimension: dimension, classCount: classCount, mean: mean, std: std, weights: best.weights, biases: best.biases)
        let trainingAccuracy = Self.accuracy(x: x, labels: labels, weights: model.weights, biases: model.biases, dimension: dimension, classCount: classCount, limit: nil)
        var outcome = Outcome(trainingAccuracy: trainingAccuracy, validationAccuracy: nil, confusions: [], epochs: best.epoch)
        if !validation.isEmpty {
            outcome.validationAccuracy = best.accuracy
            outcome.confusions = Self.confusions(x: xValidation, labels: validationLabels, weights: model.weights, biases: model.biases, dimension: dimension, classCount: classCount)
        }
        return (model, outcome)
    }

    // MARK: - Maths

    static func softmax(_ logits: [Float]) -> [Float] {
        let peak = vDSP.maximum(logits)
        var shifted = vDSP.add(-peak, logits)
        shifted = vForce.exp(shifted)
        let total = vDSP.sum(shifted)
        return vDSP.divide(shifted, total)
    }

    private static func adam(_ parameters: inout [Float], gradient: [Float], m: inout [Float], v: inout [Float], step: Float, learningRate: Float) {
        let beta1: Float = 0.9, beta2: Float = 0.999, epsilon: Float = 1e-8
        // m = β1·m + (1−β1)·g ; v = β2·v + (1−β2)·g²
        m = vDSP.add(vDSP.multiply(beta1, m), vDSP.multiply(1 - beta1, gradient))
        v = vDSP.add(vDSP.multiply(beta2, v), vDSP.multiply(1 - beta2, vDSP.multiply(gradient, gradient)))
        let correction1 = 1 - pow(beta1, step)
        let correction2 = 1 - pow(beta2, step)
        let mHat = vDSP.divide(m, correction1)
        let vHat = vDSP.divide(v, correction2)
        let denominator = vDSP.add(epsilon, vForce.sqrt(vHat))
        let update = vDSP.multiply(learningRate, vDSP.divide(mHat, denominator))
        parameters = vDSP.subtract(parameters, update)
    }

    private static func predictions(x: [Float], count: Int, weights: [Float], biases: [Float], dimension: Int, classCount: Int) -> [Int] {
        var logits = [Float](repeating: 0, count: count * classCount)
        for i in 0..<count { logits.replaceSubrange(i * classCount..<(i + 1) * classCount, with: biases) }
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(count), Int32(classCount), Int32(dimension),
                    1, x, Int32(dimension), weights, Int32(classCount), 1, &logits, Int32(classCount))
        return (0..<count).map { i in
            var index: UInt = 0
            var value: Float = 0
            logits.withUnsafeBufferPointer { pointer in
                vDSP_maxvi(pointer.baseAddress! + i * classCount, 1, &value, &index, vDSP_Length(classCount))
            }
            return Int(index)
        }
    }

    private static func accuracy(x: [Float], labels: [Int], weights: [Float], biases: [Float], dimension: Int, classCount: Int, limit: Int?) -> Double {
        let count = min(labels.count, limit ?? labels.count)
        guard count > 0 else { return 0 }
        let predicted = predictions(x: Array(x[0..<count * dimension]), count: count, weights: weights, biases: biases, dimension: dimension, classCount: classCount)
        let correct = zip(predicted, labels.prefix(count)).filter { $0 == $1 }.count
        return Double(correct) / Double(count)
    }

    private static func confusions(x: [Float], labels: [Int], weights: [Float], biases: [Float], dimension: Int, classCount: Int) -> [(label: Int, predicted: Int, count: Int)] {
        let predicted = predictions(x: x, count: labels.count, weights: weights, biases: biases, dimension: dimension, classCount: classCount)
        var counts: [String: (Int, Int, Int)] = [:]
        for (p, l) in zip(predicted, labels) where p != l {
            let key = "\(l)>\(p)"
            counts[key] = (l, p, (counts[key]?.2 ?? 0) + 1)
        }
        return counts.values.map { (label: $0.0, predicted: $0.1, count: $0.2) }.sorted { $0.count > $1.count }.prefix(15).map { $0 }
    }
}

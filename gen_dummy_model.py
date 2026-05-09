import onnx
import onnx.helper as helper
import numpy as np

# Input: [batch=1, channels=1, mels=64, frames=101]
# Output: [batch=1, classes=12]

flat_size = 6464  # 1*64*101
num_classes = 12

W = np.zeros((num_classes, flat_size), dtype=np.float32)
b = np.zeros((num_classes,), dtype=np.float32)

X = helper.make_tensor_value_info('input', onnx.TensorProto.FLOAT, [1, 1, 64, 101])
Y = helper.make_tensor_value_info('output', onnx.TensorProto.FLOAT, [1, 12])

W_init = helper.make_tensor('W', onnx.TensorProto.FLOAT, [num_classes, flat_size], W.flatten().tolist())
b_init = helper.make_tensor('b', onnx.TensorProto.FLOAT, [num_classes], b.tolist())

flatten = helper.make_node('Flatten', inputs=['input'], outputs=['flat'], axis=1)
gemm = helper.make_node('Gemm', inputs=['flat', 'W', 'b'], outputs=['output'], transB=1)

graph = helper.make_graph([flatten, gemm], 'kws_dummy', [X], [Y], [W_init, b_init])
model = helper.make_model(graph, opset_imports=[helper.make_opsetid('', 17)])
model.ir_version = 8

onnx.checker.check_model(model)
onnx.save(model, r'app/assets/models/kws_model.onnx')
print('OK - saved kws_model.onnx')

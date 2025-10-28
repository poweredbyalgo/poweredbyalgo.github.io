---
title: 学习记录——LangChain Academy Deep Agents with LangGraph 01
tags: [学习记录, LangChain]
comments: true
toc: true
---

## 课程代码

[课程链接](https://academy.langchain.com/courses/take/deep-agents-with-langgraph/)

### 自定义工具及状态

```python
from typing import Annotated, List, Literal, Union
from langchain_core.messages import ToolMessage
from langchain_core.tools import InjectedToolCallId, tool
from langgraph.prebuilt import InjectedState
from langgraph.types import Command
from langchain_core.tools import tool

from langgraph.prebuilt.chat_agent_executor import AgentState

# 合并状态的工具函数
def reduce_list(left: list | None, right: list | None) -> list:
    """Safely combine two lists, handling cases where either or both inputs might be None.

    Args:
        left (list | None): The first list to combine, or None.
        right (list | None): The second list to combine, or None.

    Returns:
        list: A new list containing all elements from both input lists.
               If an input is None, it's treated as an empty list.
    """
    if not left:
        left = []
    if not right:
        right = []
    return left + right

class CalcState(AgentState):
    """Graph State."""
    ops: Annotated[List[str], reduce_list]


@tool
def calculator_wstate(
    operation: Literal["add","subtract","multiply","divide"],
    a: Union[int, float],
    b: Union[int, float],
    state: Annotated[CalcState, InjectedState],   # not sent to LLM
    tool_call_id: Annotated[str, InjectedToolCallId] # not sent to LLM
) -> Union[int, float]:
    """Define a two-input calculator tool.

    Arg:
        operation (str): The operation to perform ('add', 'subtract', 'multiply', 'divide').
        a (float or int): The first number.
        b (float or int): The second number.
        
    Returns:
        result (float or int): the result of the operation
    Example
        Divide: result   = a / b
        Subtract: result = a - b
    """
    if operation == 'divide' and b == 0:
        return {"error": "Division by zero is not allowed."}

    # Perform calculation
    if operation == 'add':
        result = a + b
    elif operation == 'subtract':
        result = a - b
    elif operation == 'multiply':
        result = a * b
    elif operation == 'divide':
        result = a / b
    else: 
        result = "unknown operation"
    ops = [f"({operation}, {a}, {b})," ]
    return Command(
        update={
            "ops": ops,
            "messages": [
                ToolMessage(f"{result}", tool_call_id=tool_call_id)
            ],
        }
    )



@tool
def calculator(
    operation: Literal["add","subtract","multiply","divide"],
    a: Union[int, float],
    b: Union[int, float],
) -> Union[int, float]:
    """Define a two-input calculator tool.

    Arg:
        operation (str): The operation to perform ('add', 'subtract', 'multiply', 'divide').
        a (float or int): The first number.
        b (float or int): The second number.
        
    Returns:
        result (float or int): the result of the operation
    Example
        Divide: result   = a / b
        Subtract: result = a - b
    """
    if operation == 'divide' and b == 0:
        return {"error": "Division by zero is not allowed."}

    # Perform calculation
    if operation == 'add':
        result = a + b
    elif operation == 'subtract':
        result = a - b
    elif operation == 'multiply':
        result = a * b
    elif operation == 'divide':
        result = a / b
    else: 
        result = "unknown operation"
    return result
```

### Agent代码

```python
from langgraph.prebuilt import create_react_agent
from utils import format_messages

SYSTEM_PROMPT = "You are a helpful arithmetic assistant who is an expert at using a calculator."

from langchain_openai import ChatOpenAI
import os

model = ChatOpenAI(
    openai_api_key=os.getenv("DEEPSEEK_API_KEY"),
    openai_api_base=os.getenv("DEEPSEEK_API_BASE_URL"),
    model="deepseek-chat", 
)
tools = [calculator_wstate]  # new tool

# Create agent
agent = create_react_agent(
    model,
    tools,
    prompt=SYSTEM_PROMPT,
    state_schema=CalcState,  # now defining state scheme
).with_config({"recursion_limit": 20})  #recursion_limit limits the number of steps the agent will run

result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "What is 3.1 * 4.2 + 5.5 * 6.5?",
            }
        ],
    }
)

format_messages(result["messages"])
```

### utils.py

```python
"""Utility functions for displaying messages and prompts in Jupyter notebooks."""

import json

from rich.console import Console
from rich.panel import Panel
from rich.text import Text

console = Console()


from langchain_openai import ChatOpenAI
import os
def get_model():
    model = ChatOpenAI(
        openai_api_key=os.getenv("DEEPSEEK_API_KEY"),
        openai_api_base=os.getenv("DEEPSEEK_API_BASE_URL"),
        model="deepseek-chat", 
    )
    return model

def format_message_content(message):
    """Convert message content to displayable string."""
    parts = []
    tool_calls_processed = False

    # Handle main content
    if isinstance(message.content, str):
        parts.append(message.content)
    elif isinstance(message.content, list):
        # Handle complex content like tool calls (Anthropic format)
        for item in message.content:
            if item.get("type") == "text":
                parts.append(item["text"])
            elif item.get("type") == "tool_use":
                parts.append(f"\n🔧 Tool Call: {item['name']}")
                parts.append(f"   Args: {json.dumps(item['input'], indent=2, ensure_ascii=False)}")
                parts.append(f"   ID: {item.get('id', 'N/A')}")
                tool_calls_processed = True
    else:
        parts.append(str(message.content))

    # Handle tool calls attached to the message (OpenAI format) - only if not already processed
    if (
        not tool_calls_processed
        and hasattr(message, "tool_calls")
        and message.tool_calls
    ):
        for tool_call in message.tool_calls:
            parts.append(f"\n🔧 Tool Call: {tool_call['name']}")
            parts.append(f"   Args: {json.dumps(tool_call['args'], indent=2, ensure_ascii=False)}")
            parts.append(f"   ID: {tool_call['id']}")

    return "\n".join(parts)


def format_messages(messages):
    """Format and display a list of messages with Rich formatting."""
    for m in messages:
        msg_type = m.__class__.__name__.replace("Message", "")
        content = format_message_content(m)

        if msg_type == "Human":
            console.print(Panel(content, title="🧑 Human", border_style="blue"))
        elif msg_type == "Ai":
            console.print(Panel(content, title="🤖 Assistant", border_style="green"))
        elif msg_type == "Tool":
            console.print(Panel(content, title="🔧 Tool Output", border_style="yellow"))
        else:
            console.print(Panel(content, title=f"📝 {msg_type}", border_style="white"))


def format_message(messages):
    """Alias for format_messages for backward compatibility."""
    return format_messages(messages)


def show_prompt(prompt_text: str, title: str = "Prompt", border_style: str = "blue"):
    """Display a prompt with rich formatting and XML tag highlighting.

    Args:
        prompt_text: The prompt string to display
        title: Title for the panel (default: "Prompt")
        border_style: Border color style (default: "blue")
    """
    # Create a formatted display of the prompt
    formatted_text = Text(prompt_text)
    formatted_text.highlight_regex(r"<[^>]+>", style="bold blue")  # Highlight XML tags
    formatted_text.highlight_regex(
        r"##[^#\n]+", style="bold magenta"
    )  # Highlight headers
    formatted_text.highlight_regex(
        r"###[^#\n]+", style="bold cyan"
    )  # Highlight sub-headers

    # Display in a panel for better presentation
    console.print(
        Panel(
            formatted_text,
            title=f"[bold green]{title}[/bold green]",
            border_style=border_style,
            padding=(1, 2),
        )
    )

# more expressive runner
async def stream_agent(agent, query, config=None):
    async for graph_name, stream_mode, event in agent.astream(
        query,
        stream_mode=["updates", "values"], 
        subgraphs=True,
        config=config
    ):
        if stream_mode == "updates":
            print(f'Graph: {graph_name if len(graph_name) > 0 else "root"}')
            
            node, result = list(event.items())[0]
            print(f'Node: {node}')
            
            for key in result.keys():
                if "messages" in key:
                    # print(f"Messages key: {key}")
                    format_messages(result[key])
                    break
        elif stream_mode == "values":
            current_state = event

    return current_state

```

## 问题与回答整理

### 问题1：在`calculator_wstate`工具中，尽管`state`参数未被直接使用，状态是如何更新的？

**回答：**

在`calculator_wstate`工具中，状态更新是通过返回`Command`对象实现的，而不是直接使用`state`参数。具体机制如下：

1. **`state`参数的作用**：
   
   ```python
   state: Annotated[CalcState, InjectedState]
   ```
   这个参数声明了工具需要访问状态，但实际上工具内部并不直接使用它。它更像是一个标记，告诉框架这个工具需要状态访问权限。
   
2. **状态更新的实际机制**：
   工具返回一个`Command`对象，其中包含`update`字段：
   ```python
   return Command(
       update={
           "ops": ops,  # 更新操作历史
           "messages": [  # 添加新的工具消息
               ToolMessage(f"{result}", tool_call_id=tool_call_id)
           ],
       }
   )
   ```

3. **框架处理流程**：
   - 工具返回`Command`对象后，LangGraph框架会自动处理这个对象
   - 框架提取`update`字段中的内容，并更新状态
   - "ops"字段使用`reduce_list`函数合并新旧值
   - "messages"字段将新的`ToolMessage`添加到消息历史中

这种设计实现了状态更新与业务逻辑的分离，使工具代码更加清晰，同时保持了状态管理的一致性。

---

### 问题2：`Annotated[List[str], reduce_list]`的含义是什么？

`Annotated[List[str], reduce_list]`是Python中的一种类型注解，结合了`typing`模块的`Annotated`和自定义的`reduce_list`函数，用于控制LangGraph中状态更新的行为。

1. **`Annotated`的作用**：
   `Annotated`来自`typing`模块，允许为类型添加元数据而不影响运行时行为。格式为：
   ```python
   Annotated[类型, 元数据1, 元数据2, ...]
   ```

2. **`reduce_list`函数**：
   ```python
   def reduce_list(left: list | None, right: list | None) -> list:
       """安全地合并两个列表，处理None值的情况"""
       if not left:
           left = []
       if not right:
           right = []
       return left + right
   ```
   这个函数处理两个可能为None的列表，将它们合并为一个新列表。

3. **在LangGraph中的应用**：
   在`CalcState`类中：
   ```python
   class CalcState(AgentState):
       ops: Annotated[List[str], reduce_list]
   ```
   这个注解告诉LangGraph：
   - `ops`字段是一个字符串列表
   - 当更新此字段时，使用`reduce_list`函数合并新旧值
   - 而不是简单地覆盖旧值

4. **工作流程示例**：
   - 当前状态：`ops = ["(add, 1, 2),"]`
   - 工具返回：`Command(update={"ops": ["(multiply, 3, 4),"]})`
   - LangGraph调用`reduce_list(["(add, 1, 2),"], ["(multiply, 3, 4),"])`
   - 结果：`ops = ["(add, 1, 2),", "(multiply, 3, 4),"]`

这种模式在LangGraph中非常常见，用于实现状态的累积和合并，而不是简单的覆盖。

---

### 问题3：`Annotated`的第二个参数为reducer是否是LangGraph的约定？

是的，`Annotated`的第二个参数为reducer是LangGraph的明确约定和核心特性。这是LangGraph状态管理的关键设计模式。

1. **LangGraph中的约定**：
   在LangGraph中，当使用`Annotated[type, reducer]`格式时，第二个参数被解释为reducer函数，用于控制状态更新的策略。

2. **Python中的实现**：
   ```python
   # 使用内置函数作为reducer
   ops: Annotated[list, operator.add]
   
   # 使用自定义函数作为reducer
   ops: Annotated[List[str], reduce_list]
   
   # 使用LangGraph内置的消息合并器
   messages: Annotated[list, add_messages]
   ```

3. **TypeScript中的实现**：
   在TypeScript中，类似功能通过Zod状态和register方法实现：
   ```typescript
   const stateSchema = z.object({
     ops: z.array(z.string()).register({
       meta: {
         reducer: customReducerFunction
       }
     })
   });
   ```

4. **reducer的作用**：
   - **默认行为**：没有reducer的字段在更新时会被直接覆盖
   - **reducer行为**：有reducer的字段在更新时会调用reducer函数合并新旧值
   - **并发处理**：reducer帮助解决并发更新时的冲突问题

5. **官方文档支持**：
   LangGraph官方文档明确推荐这种模式，并在多个示例中使用它来实现各种状态管理需求，如消息历史累积、操作记录等。

因此，将`Annotated`的第二个参数用作reducer是LangGraph框架的核心约定，是开发者应该遵循的标准模式。

---

### 问题4：`InjectedToolCallId`和`InjectedState`是如何实现的？

**回答：**

`InjectedState`和`InjectedToolCallId`是LangGraph框架中的特殊标记类，用于在工具函数中注入上下文信息。它们的实现基于以下几个关键机制：

#### InjectedState的实现原理

1. **类型注解标记**：
   ```python
   state: Annotated[CalcState, InjectedState]
   ```
   这里`Annotated`的第二个参数`InjectedState`是一个标记类，告诉框架这个参数需要特殊处理。

2. **运行时注入机制**：
   - LangGraph在调用工具前会检查函数签名
   - 如果发现参数带有`InjectedState`标记，框架会自动将当前状态注入到这个参数中
   - 这个注入过程对用户透明，不需要手动传递

3. **隐藏于LLM**：
   - 带有`InjectedState`标记的参数不会出现在工具的schema中
   - 这意味着LLM不会看到这些参数，也不会尝试为它们提供值
   - 只有框架本身会为这些参数提供值

#### InjectedToolCallId的实现原理

1. **工具调用关联**：
   ```python
   tool_call_id: Annotated[str, InjectedToolCallId]
   ```
   这个参数会自动接收当前工具调用的唯一标识符

2. **消息关联机制**：
   - 在`calculator_wstate`工具中，返回的`ToolMessage`需要与原始工具调用关联
   - 通过`tool_call_id`，框架知道这个`ToolMessage`是对哪个工具调用的响应
   - 这确保了对话历史的正确性和连贯性

3. **内部实现流程**：
   - 当LLM决定调用工具时，框架生成唯一的`tool_call_id`
   - 工具执行时，通过`InjectedToolCallId`将此ID注入到工具函数中
   - 工具返回的`ToolMessage`使用此ID，框架将其正确添加到消息历史中

#### 框架层面的实现

这两种注入机制是LangGraph框架的核心特性，实现方式大致如下：

1. **函数签名解析**：
   - 框架使用反射机制解析工具函数的参数类型注解
   - 识别出带有`InjectedState`或`InjectedToolCallId`标记的参数

2. **参数预处理**：
   - 在调用工具前，框架准备所有参数
   - 对于普通参数，使用LLM提供的值
   - 对于注入标记参数，使用框架内部提供的值

3. **透明处理**：
   - 整个注入过程对工具开发者透明
   - 开发者只需添加正确的类型注解，无需关心具体实现

这种设计模式使得工具可以访问上下文信息（如状态和工具调用ID），同时保持工具接口的简洁性，并且不会暴露这些内部细节给LLM。这是LangGraph实现高级代理功能的关键机制之一。

---

### 总结

LangChain/LangGraph的注入机制是一套精心设计的系统，通过类型注解和标记类实现了：

1. **状态注入**：通过`InjectedState`让工具访问当前代理状态
2. **工具调用ID注入**：通过`InjectedToolCallId`关联工具调用与响应
3. **状态更新控制**：通过`Annotated`和reducer函数控制状态更新策略

这些机制共同工作，使开发者能够构建复杂的代理系统，同时保持代码的清晰和可维护性。
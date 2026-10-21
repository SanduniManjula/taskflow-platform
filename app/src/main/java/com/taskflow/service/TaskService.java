package com.taskflow.service;

import com.taskflow.dto.TaskRequest;
import com.taskflow.dto.TaskResponse;
import com.taskflow.entity.Task;
import com.taskflow.entity.TaskStatus;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.repository.TaskRepository;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class TaskService {
    private final TaskRepository repository;
    public TaskService(TaskRepository repository) { this.repository = repository; }

    @Transactional
    public TaskResponse create(TaskRequest request) {
        Task task = new Task(request.title().trim(), request.description(),
                request.status() == null ? TaskStatus.TODO : request.status());
        return TaskResponse.from(repository.save(task));
    }

    @Transactional(readOnly = true)
    public List<TaskResponse> list() {
        return repository.findAll(Sort.by(Sort.Direction.DESC, "createdAt"))
                .stream().map(TaskResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public TaskResponse get(Long id) { return TaskResponse.from(find(id)); }

    @Transactional
    public TaskResponse update(Long id, TaskRequest request) {
        Task task = find(id);
        task.update(request.title().trim(), request.description(),
                request.status() == null ? task.getStatus() : request.status());
        return TaskResponse.from(repository.save(task));
    }

    @Transactional
    public void delete(Long id) {
        Task task = find(id);
        repository.delete(task);
    }

    private Task find(Long id) {
        return repository.findById(id).orElseThrow(() -> new TaskNotFoundException(id));
    }
}

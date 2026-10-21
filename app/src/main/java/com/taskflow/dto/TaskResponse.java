package com.taskflow.dto;

import com.taskflow.entity.Task;
import com.taskflow.entity.TaskStatus;
import java.time.Instant;

public record TaskResponse(Long id, String title, String description, TaskStatus status,
                           Instant createdAt, Instant updatedAt) {
    public static TaskResponse from(Task task) {
        return new TaskResponse(task.getId(), task.getTitle(), task.getDescription(),
                task.getStatus(), task.getCreatedAt(), task.getUpdatedAt());
    }
}

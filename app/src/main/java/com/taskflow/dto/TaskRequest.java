package com.taskflow.dto;

import com.taskflow.entity.TaskStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TaskRequest(
    @NotBlank(message = "title is required")
    @Size(max = 120, message = "title must be at most 120 characters")
    String title,
    @Size(max = 2000, message = "description must be at most 2000 characters")
    String description,
    TaskStatus status
) {}
